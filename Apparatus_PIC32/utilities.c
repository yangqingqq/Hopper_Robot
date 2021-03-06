#include <stdio.h>
#include "NU32.h"
#include "utilities.h"
#include "linmot.h" 
 
static volatile mode MODE;            	// Operating mode
static volatile control_data_t DATA;    // Struct containing data arrays
static volatile int N;                  // Number of samples to store
static volatile unsigned int read = 0, write = 0; // circular buffer indexes

void setMODE(mode newMODE) {  // Set mode
    MODE = newMODE;     // Update global MODE
}

mode getMODE() {  // Return mode
    return MODE;
}

void setN_client(void)          // Recieve number of values to store in position data arrays from client
{                   
    char buffer[10];            // Buffer holding number of samples
    NU32_ReadUART3(buffer,10);  // Read number of samples from client
    sscanf(buffer,"%d",&N);     // Update global N
}

int getN(void){
    return N;                   // Return number of samples to be stored
}

void write_reference_position(int position, int index)     // Write reference position to data array
{
    DATA.position_reference[index] = position;
}

int get_reference_position(int index)           		// Return reference position to given index
{
	return DATA.position_reference[index];
}

void write_reference_Fz(short force, int index)
{
	DATA.Fz_reference[index] = force;
}

short get_reference_Fz(int index)
{
	return DATA.Fz_reference[index];
}

int buffer_empty() {    // return true if the buffer is empty (read = write)
  return read == write; 
}

int buffer_full() {     // return true if the buffer is full.  
  return (write + 1) % BUFLEN == read; 
}

int buffer_read_position() {	// reads position from current buffer location; assumes buffer not empty
	int pos = DATA.position_actual[read];
	return pos;
}

float buffer_read_current() {	// reads current from current buffer location; assumes buffer not empty 
	float current = DATA.current_actual[read];
	return current;
}

short buffer_read_Fz() {
	short force = DATA.Fz_actual[read];
	return force;
}

short buffer_read_Tx() {
	short torque = DATA.Tx_actual[read];
	return torque;
}

short buffer_read_Ty() {
	short torque = DATA.Ty_actual[read];
	return torque;
}

void buffer_read_increment() {	// increment the buffer read location
	++read;	// increment buffer read index
	if (read >= BUFLEN) {	// wraparound read location if necessary
		read = 0;
	}
}

void buffer_write(int actual_position, float actual_current, short actual_Fz, short actual_Tx, short actual_Ty) { 	// write data to buffer
  if(!buffer_full()) {        // if the buffer is full the data is lost
    DATA.position_actual[write] = actual_position;	// write motor position to buffer
	DATA.current_actual[write] = actual_current;	// write motor current to buffer
	DATA.Fz_actual[write] = actual_Fz;		// write force to buffer
	DATA.Tx_actual[write] = actual_Tx;
	DATA.Ty_actual[write] = actual_Ty;
    ++write;                  // increment the write index and wrap around if necessary
    if(write >= BUFLEN) {
      write = 0;
    }
  }
}

void send_data(void)
{
	int sent = 0;
	char msg[75];
	sprintf(msg, "%d\r\n",getN()/DECIMATION);	// tell the client how many samples to expect
	NU32_WriteUART3(msg);
	
	for(sent = 0; sent < (N/DECIMATION); ++sent) { // send the samples to the client
		while(buffer_empty()) { ; }             								// wait for data to be in the queue
		sprintf(msg,"%d %f %hi %hi %hi\r\n",buffer_read_position(),buffer_read_current(),buffer_read_Fz(),buffer_read_Tx(),buffer_read_Ty());  // read from buffer 
		NU32_WriteUART3(msg);													// send data over uart
		buffer_read_increment();												// increment buffer read index
  }
}
    