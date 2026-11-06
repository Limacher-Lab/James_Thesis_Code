#define _USE_MATH_DEFINES
//Required include files
#include <algorithm>
#include <stdio.h>	
#include <string>
#include <iostream>
#include <iomanip>
#include <chrono>
#include <cmath>
#include <thread>
#include <fstream>
#include "pubSysCls.h"
#include "MatlabEngine.hpp"
#include "MatlabDataArray.hpp"

using namespace sFnd;
using namespace std;
using namespace std::chrono;
using namespace matlab::engine;


#define TIME_TILL_TIMEOUT	10000	//The timeout used for homing(ms)

string saveFolderDir = "C:/Users/James/Desktop/Calibration/Galoce/Tightly Cable Managed Runs/Post Tear Flap Check/";

// Send message and wait for newline
void msgUser(const char *msg) {
	cout << msg;
	getchar();
}

// get a rough estimate of how much overhead there is in calling buzy_sleep()
std::chrono::nanoseconds calc_overhead() {
	constexpr size_t tests = 1001;
	constexpr auto timer = 200us;

	auto init = [&timer]() {
		auto end = steady_clock::now() + timer;
		while (steady_clock::now() < end);
		};

	time_point<steady_clock> start;
	nanoseconds dur[tests];

	for (auto& d : dur) {
		start = steady_clock::now();
		init();
		d = steady_clock::now() - start - timer;
	}
	std::sort(std::begin(dur), std::end(dur));
	// get the median value or something a little less as in this example:
	return dur[tests / 3];
}

// initialize the overhead constant that will be used in busy_sleep()
static const std::chrono::nanoseconds overhead = calc_overhead();
static const std::chrono::nanoseconds posOverhead(3391000);
static const std::chrono::nanoseconds velOverhead(3386000);
static const std::chrono::nanoseconds accOverhead(3385000);

static const std::chrono::nanoseconds t_wait(3571428);

inline void pos_busy_sleep(std::chrono::nanoseconds t) {
	auto end = std::chrono::steady_clock::now() + t - overhead-posOverhead;
	while (std::chrono::steady_clock::now() < end);
}

inline void vel_busy_sleep(std::chrono::nanoseconds t) {
	auto end = std::chrono::steady_clock::now() + t - overhead - velOverhead;
	while (std::chrono::steady_clock::now() < end);
}

inline void acc_busy_sleep(std::chrono::nanoseconds t) {
	auto end = std::chrono::steady_clock::now() + t - overhead - accOverhead;
	while (std::chrono::steady_clock::now() < end);
}


void posRefresh(vector<vector<vector<double>>>& dataVector, int inode, INode* m_node, double t_now, bool* track, SysManager* myMgr) {
	int row = 0;
	double t_Now = 0;
	double t_Prev = (myMgr->TimeStampMsec() - t_now) / 1000;

	while (*track == false) {
		pos_busy_sleep(t_wait);
		t_Prev = (myMgr->TimeStampMsec() - t_now) / 1000;
		m_node->Motion.PosnMeasured.Refresh();
		dataVector[inode][row][1] = m_node->Motion.PosnMeasured;
		dataVector[inode][row][0] = t_Prev;
		row++;
	}

}

void velRefresh(vector<vector<vector<double>>>& dataVector, int inode, INode* m_node, double t_now, bool* track, SysManager* myMgr) {
	int row = 0;
	double t_Now = 0;
	double t_Prev = (myMgr->TimeStampMsec() - t_now) / 1000;

	while (*track == false) {
		vel_busy_sleep(t_wait);
		t_Prev = (myMgr->TimeStampMsec() - t_now) / 1000;
		m_node->Motion.VelMeasured.Refresh();
		dataVector[inode][row][3] = m_node->Motion.VelMeasured;
		dataVector[inode][row][2] = t_Prev;
		row++;
	}

}

void torRefresh(vector<vector<vector<double>>>& dataVector, int inode, INode* m_node, double t_now, bool* track, SysManager* myMgr) {
	int row = 0;
	double t_Now = 0;
	double t_Prev = (myMgr->TimeStampMsec() - t_now) / 1000;
	while (*track == false) {
		acc_busy_sleep(t_wait);
		t_Prev = (myMgr->TimeStampMsec() - t_now) / 1000;
		m_node->Motion.TrqMeasured.Refresh();
		dataVector[inode][row][5] = m_node->Motion.TrqMeasured;
		dataVector[inode][row][4] = t_Prev;
		row++;
	}

}

string fileName;

//*********************************************************************************
//This program will load configuration files onto each node connected to the port, then executes
//sequential repeated moves on each axis.
//*********************************************************************************

int main(int argc, char* argv[])
{	
	msgUser("Motion Example starting. Press Enter to continue.");

	size_t portCount = 0;
	std::vector<std::string> comHubPorts;


	//Create the SysManager object. This object will coordinate actions among various ports
	// and within nodes. In this example we use this object to setup and open our port.
	SysManager* myMgr = SysManager::Instance();							//Create System Manager myMgr

	//This will try to open the port. If there is an error/exception during the port opening,
	//the code will jump to the catch loop where detailed information regarding the error will be displayed;
	//otherwise the catch loop is skipped over
	try
	{ 
		SysManager::FindComHubPorts(comHubPorts);
		printf("Found %d SC Hubs\n", comHubPorts.size());

		for (portCount = 0; portCount < comHubPorts.size() && portCount < NET_CONTROLLER_MAX; portCount++) {
			
			myMgr->ComHubPort(portCount, comHubPorts[portCount].c_str()); 	//define the first SC Hub port (port 0) to be associated 
			// with COM portnum (as seen in device manager)
		}

		if (portCount < 0) {

			printf("Unable to locate SC hub port\n");

			msgUser("Press any key to continue."); //pause so the user can see the error message; waits for user to press a key

			return -1;  //This terminates the main program
		}
		//printf("\n I will now open port \t%i \n \n", portnum);
		myMgr->PortsOpen(portCount);				//Open the port

		for (size_t i = 0; i < portCount; i++) {
			IPort& myPort = myMgr->Ports(i);

			printf(" Port[%d]: state=%d, nodes=%d\n",
				myPort.NetNumber(), myPort.OpenState(), myPort.NodeCount());



			//Once the code gets past this point, it can be assumed that the Port has been opened without issue
			//Now we can get a reference to our port object which we will use to access the node objects

			for (size_t iNode = 0; iNode < myPort.NodeCount(); iNode++) {
				// Create a shortcut reference for a node
				INode& theNode = myPort.Nodes(iNode);

				//theNode.EnableReq(false);				//Ensure Node is disabled before loading config file

				myMgr->Delay(200);
				


				//theNode.Setup.ConfigLoad("2326_5th_g.mtr");


				printf("   Node[%d]: type=%d\n", int(iNode), theNode.Info.NodeType());
				printf("            userID: %s\n", theNode.Info.UserID.Value());
				printf("        FW version: %s\n", theNode.Info.FirmwareVersion.Value());
				printf("          Serial #: %d\n", theNode.Info.SerialNumber.Value());
				printf("             Model: %s\n", theNode.Info.Model.Value());

				//The following statements will attempt to enable the node.  First,
				// any shutdowns or NodeStops are cleared, finally the node is enabled
				theNode.Status.AlertsClear();					//Clear Alerts on node 
				theNode.Motion.NodeStopClear();	//Clear Nodestops on Node  				
				//theNode.EnableReq(true);					//Enable node 
				//At this point the node is enabled
				printf("Node \t%zi enabled\n", iNode);
				double timeout = myMgr->TimeStampMsec() + TIME_TILL_TIMEOUT;	//define a timeout in case the node is unable to enable
				//This will loop checking on the Real time values of the node's Ready status
				while (!theNode.Motion.IsReady()) {
					if (myMgr->TimeStampMsec() > timeout) {
						printf("Error: Timed out waiting for Node %d to enable\n", iNode);
						msgUser("Press any key to continue."); //pause so the user can see the error message; waits for user to press a key
						return -2;
					}
				}
				//At this point the Node is enabled, and we will now check to see if the Node has been homed
				//Check the Node to see if it has already been homed, 
				if (theNode.Motion.Homing.HomingValid())
				{
					theNode.Motion.Homing.SignalComplete();
					if (theNode.Motion.Homing.WasHomed())
					{
						printf("Node %d has already been homed, current position is: \t%8.0f \n", iNode, theNode.Motion.PosnMeasured.Value());
						printf("Rehoming Node... \n");
					}
					else
					{
						printf("Node [%d] has not been homed.  Homing Node now...\n", iNode);
					}
					//Now we will home the Node

					timeout = myMgr->TimeStampMsec() + TIME_TILL_TIMEOUT;	//define a timeout in case the node is unable to enable
					// Basic mode - Poll until disabled
					while (!theNode.Motion.Homing.WasHomed()) {
						if (myMgr->TimeStampMsec() > timeout) {
							printf("Node did not complete homing:  \n\t -Ensure Homing settings have been defined through ClearView. \n\t -Check for alerts/Shutdowns \n\t -Ensure timeout is longer than the longest possible homing move.\n");
							msgUser("Press any key to continue."); //pause so the user can see the error message; waits for user to press a key
							return -2;
						}
					}
					printf("Node completed homing\n");
				}
				else {
					printf("Node[%d] has not had homing setup through ClearView.  The node will not be homed.\n", iNode);
				}

			}

			///////////////////////////////////////////////////////////////////////////////////////
			//At this point we will execute 10 rev moves sequentially on each axis
			//////////////////////////////////////////////////////////////////////////////////////
			INode& stroke_Node = myPort.Nodes(0);
			INode& pitch_Node = myPort.Nodes(1);

			char totalChar;
			ifstream totalLoop("totalLoops.txt");
			totalLoop.get(totalChar);
			totalLoop.close();

			while (totalChar != 'y') {
				ifstream totalLoop("totalLoops.txt");
				totalLoop.get(totalChar);
				totalLoop.close();
			}

			while (totalChar == 'y') {
				bool track = false;
				int row = 0;
				int pts = 410 * 70;
				vector<vector<vector<double>>> dataStroke(1, vector<vector<double>>(pts, vector<double>(6)));
				vector<vector<vector<double>>> dataPitch(1, vector<vector<double>>(pts, vector<double>(6)));
				vector<double> list_tFunc(pts);

				//stroke_Node.Status.RT.Refresh();
				//printf("Waiting for motion to start. \n");
				//while (!stroke_Node.Status.RT.Value().cpm.InB) {
				//	stroke_Node.Status.RT.Refresh();
				//}

				ifstream nameFile("fileName.txt");
				string name;
				char nameIsUpdated;
				getline(nameFile, name);
				nameFile.get(nameIsUpdated);
				nameFile.close();

				while (nameIsUpdated != 'y') {
					ifstream nameFile("fileName.txt");
					getline(nameFile, name);
					nameFile.get(nameIsUpdated);
					nameFile.close();
				}

				printf("Waiting to collect data.\n");

				char singleChar;
				ifstream mainLoop("mainLoop.txt");
				mainLoop.get(singleChar);
				mainLoop.close();

				while (singleChar != 'y') {
					ifstream mainLoop("mainLoop.txt");
					mainLoop.get(singleChar);
					mainLoop.close();
				}

				printf("Starting Data Collection for ");
				cout << name << endl;
				double t_Now = myMgr->TimeStampMsec();
				thread th1(posRefresh, ref(dataStroke), 0, &stroke_Node, t_Now, &track, myMgr);
				thread th2(velRefresh, ref(dataStroke), 0, &stroke_Node, t_Now, &track, myMgr);
				thread th3(torRefresh, ref(dataStroke), 0, &stroke_Node, t_Now, &track, myMgr);
				thread th4(posRefresh, ref(dataPitch), 0, &pitch_Node, t_Now, &track, myMgr);
				thread th5(velRefresh, ref(dataPitch), 0, &pitch_Node, t_Now, &track, myMgr);
				thread th6(torRefresh, ref(dataPitch), 0, &pitch_Node, t_Now, &track, myMgr);


				while (singleChar == 'y') {
					ifstream mainLoop("mainLoop.txt");
					mainLoop.get(singleChar);
					mainLoop.close();
				}
				track = true;

				th1.join();
				th2.join();
				th3.join();
				th4.join();
				th5.join();
				th6.join();


				fileName = saveFolderDir + name + " (Stroke)" + ".csv";
				ofstream dataFile(fileName);
				for (int k = 0; k < dataStroke[0].size(); k++) {
					for (int l = 0; l < dataStroke[0][0].size(); l++) {
						dataFile << setprecision(9) << dataStroke[0][k][l] << ",";
					}
					dataFile << endl;
				}
				fileName.clear();

				fileName = saveFolderDir + name + " (Pitch)" + ".csv";
				ofstream dataFile2(fileName);
				for (int k = 0; k < dataPitch[0].size(); k++) {
					for (int l = 0; l < dataPitch[0][0].size(); l++) {
						dataFile2 << setprecision(9) << dataPitch[0][k][l] << ",";
					}
					dataFile2 << endl;
				}
				fileName.clear();

				ifstream totalLoop("totalLoops.txt");
				totalLoop.get(totalChar);
				char totalIsUpdated;
				totalLoop.get(totalIsUpdated);
				totalLoop.close();

				while (totalIsUpdated != 'y') {
					ifstream totalLoop("totalLoops.txt");
					totalLoop.get(totalChar);
					totalLoop.get(totalIsUpdated);
					totalLoop.close();
				}
				
			}

		//////////////////////////////////////////////////////////////////////////////////////////////
		//After moves have completed Disable node, and close ports
		//////////////////////////////////////////////////////////////////////////////////////////////
			//printf("Disabling nodes, and closing port\n");
			////Disable Nodes

			//for (size_t iNode = 0; iNode < myPort.NodeCount(); iNode++) {
			//	// Create a shortcut reference for a node
			//	myPort.Nodes(iNode).EnableReq(false);
			//}
		}
	}
	catch (mnErr& theErr)
	{
		printf("Failed to disable Nodes n\n");
		//This statement will print the address of the error, the error code (defined by the mnErr class), 
		//as well as the corresponding error message.
		printf("Caught error: addr=%d, err=0x%08x\nmsg=%s\n", theErr.TheAddr, theErr.ErrorCode, theErr.ErrorMsg);

		msgUser("Press any key to continue."); //pause so the user can see the error message; waits for user to press a key
		return 0;  //This terminates the main program
	}

	// Close down the ports
	//myMgr->PortsClose();

	msgUser("Press any key to continue."); //pause so the user can see the error message; waits for user to press a key
	return 0;			//End program
}

