
/*
 
 Copyright (c) 2012 RedBearLab
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
    #import <CoreBluetooth/CoreBluetooth.h>
#else
    #import <IOBluetooth/IOBluetooth.h>
#endif


@protocol BLEDelegate

@optional
- (void)BLEDidConnect;
- (void)BLEDidDisconnect;
- (void)BLEDidUpdateRSSI:(NSNumber *)rssi;
- (void)BLEDidReceiveData:(unsigned char *)data length:(int)length;

@end


@interface BLE : NSObject


@property(nonatomic,assign) id<BLEDelegate> delegate;
@property(strong, nonatomic) CBCentralManager *centralManager; // this phone
@property(strong, nonatomic) NSMutableArray *peripherals; // BLE devices
@property(strong, nonatomic) CBPeripheral *activePeripheral; // BLE device


- (id)initWithDelegate:(id)delegate;

- (void)enableWrite;
- (void)enableReadNotification:(CBPeripheral *)p;
- (void)read;
- (void)writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral data:(NSData *)data;

- (UInt16)readLibVer;
- (UInt16)readFrameworkVersion;
- (NSString *)readVendorName;
- (BOOL)isConnected;
- (int)readRSSI;
- (void)write:(NSData *)data;

- (int)controlSetup:(int)s;
- (int)findBLEPeripherals:(int)timeout;
- (void)connectPeripheral:(CBPeripheral *)peripheral;

- (UInt16)swap:(UInt16)s;
- (const char *)centralManagerStateToString:(int)state;
- (void)scanTimer:(NSTimer *)timer;
- (void)printKnownPeripherals;
- (void)printPeripheralInfo:(CBPeripheral*)peripheral;

- (void)getAllServicesFromPeripheral:(CBPeripheral *)peripheral;
- (void)getAllCharacteristicsFromPeripheral:(CBPeripheral *)peripheral;
- (CBService *)findServiceFromUUID:(CBUUID *)UUID peripheral:(CBPeripheral *)peripheral;
- (CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service;
- (const char *)UUIDToString:(CFUUIDRef)UUID;
- (const char *)CBUUIDToString:(CBUUID *)UUID;
- (int)compareCBUUID:(CBUUID *)UUID1 UUID2:(CBUUID *)UUID2;
- (int)compareCBUUIDToInt:(CBUUID *)UUID1 UUID2:(UInt16)UUID2;
- (UInt16)CBUUIDToInt:(CBUUID *)UUID;
- (int)UUIDSAreEqual:(CFUUIDRef)UUID1 UUID2:(CFUUIDRef)UUDID2;

@end
