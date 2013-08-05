
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


@protocol BLEShieldDelegate

@optional
- (void)BLEDidConnect;
- (void)BLEDidDisconnect;
- (void)BLEDidUpdateRSSI:(NSNumber *)rssi;
- (void)BLEDidReceiveData:(unsigned char *)data length:(int)length;

@end


@interface BLEShield : NSObject

@property(nonatomic,assign) id<BLEShieldDelegate> delegate;
@property(strong, nonatomic) CBCentralManager *centralManager; // this phone
@property(strong, nonatomic) NSMutableArray *peripherals; // BLE devices
@property(strong, nonatomic) CBPeripheral *activePeripheral; // BLE device

- (id)initWithDelegate:(id)delegate;

- (int)controlSetup:(int)s;
- (int)findBLEPeripherals:(int)timeout;
- (void)connectPeripheral:(CBPeripheral *)peripheral;

- (BOOL)isConnected;
- (int)readRSSI;
- (void)write:(NSData *)data;

@end
