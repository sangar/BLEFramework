
/*
 
 Copyright (c) 2012 RedBearLab
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

#import "BLEShield.h"
#import "BLEDefines.h"


@interface BLEShield () <CBCentralManagerDelegate, CBPeripheralDelegate>

- (void)readValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral;
- (void)notification:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral on:(BOOL)on;

- (void)readVendorNameFromPeripheral;
- (void)readLibVerFromPeripheral;

#if !TARGET_OS_IPHONE
- (BOOL)isLECapableHardware;
#endif

- (void)enableWrite;
- (void)enableReadNotification:(CBPeripheral *)p;
- (void)read;
- (void)writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral data:(NSData *)data;

- (UInt16)readLibVer;
- (UInt16)readFrameworkVersion;
- (NSString *)readVendorName;

- (UInt16)swap:(UInt16)s;
- (const char *)centralManagerStateToString:(int)state;
- (void)scanTimer:(NSTimer *)timer;

- (void)printKnownPeripherals;
- (void)printPeripheralInfo:(CBPeripheral*)peripheral;

- (void)getAllServicesFromPeripheral:(CBPeripheral *)peripheral;
- (void)getAllCharacteristicsFromPeripheral:(CBPeripheral *)peripheral;
- (CBService *)findServiceFromUUID:(CBUUID *)UUID peripheral:(CBPeripheral *)peripheral;
- (CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service;
- (NSString *)UUIDToString:(NSUUID *)UUID;
- (const char *)CBUUIDToString:(CBUUID *)UUID;
- (BOOL)compareCBUUID:(CBUUID *)UUID1 UUID2:(CBUUID *)UUID2;
- (BOOL)compareCBUUIDToInt:(CBUUID *)UUID1 UUID2:(UInt16)UUID2;
- (UInt16)CBUUIDToInt:(CBUUID *)UUID;
- (BOOL)UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUDID2;

@end


@implementation BLEShield


@synthesize delegate = _delegate;
@synthesize centralManager = _centralManager;
@synthesize peripherals = _peripherals;
@synthesize activePeripheral = _activePeripheral;


static UInt16 libver = 0;
static unsigned char vendor_name[20] = {0};
static bool isConnected = false;
static int rssi = 0;


- (id)initWithDelegate:(id)delegate {
    self = [self init];
    self.delegate = delegate;
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}


- (void)enableWrite {
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_DEVICE_RESET_RX_UUID];
    unsigned char bytes[] = {0x01};
    NSData *data = [[NSData alloc] initWithBytes:bytes length:1];
    [self writeValue:uuid_service characteristicUUID:uuid_char peripheral:_activePeripheral data:data];
}

- (void)readLibVerFromPeripheral {
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_DEVICE_LIB_VERSION_UUID];
    
    [self readValue:uuid_service characteristicUUID:uuid_char peripheral:_activePeripheral];
}

- (void)readVendorNameFromPeripheral {
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_DEVICE_VENDOR_NAME_UUID];
    
    [self readValue:uuid_service characteristicUUID:uuid_char peripheral:_activePeripheral];
}

- (BOOL)isConnected {
    return isConnected;
}

- (void)read {
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_DEVICE_RX_UUID];
    
    [self readValue:uuid_service characteristicUUID:uuid_char peripheral:_activePeripheral];
}

- (void)write:(NSData *)data {
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_DEVICE_TX_UUID];
    
    [self writeValue:uuid_service characteristicUUID:uuid_char peripheral:_activePeripheral data:data];
}

- (void)enableReadNotification:(CBPeripheral *)peripheral {
    CBUUID *uuid_service = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *uuid_char = [CBUUID UUIDWithString:@BLE_DEVICE_RX_UUID];
    
    [self notification:uuid_service characteristicUUID:uuid_char peripheral:peripheral on:YES];
}

- (void)notification:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral on:(BOOL)on {
    CBService *service = [self findServiceFromUUID:serviceUUID peripheral:peripheral];
    
    if (!service) {
        NSLog(@"Could not find service with UUID %s on peripheral with UUID %@",
              [self CBUUIDToString:serviceUUID],[self UUIDToString:peripheral.identifier]);
        return;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        NSLog(@"Could not find characteristic with UUID %s on service with UUID %s on peripheral with UUID %@",
              [self CBUUIDToString:characteristicUUID], [self CBUUIDToString:serviceUUID], [self UUIDToString:peripheral.identifier]);
        return;
    }
    
    [peripheral setNotifyValue:on forCharacteristic:characteristic];
}

- (int)readRSSI {
    return rssi;
}

- (UInt16)readLibVer {
    return libver;
}

- (UInt16)readFrameworkVersion {
    return BLE_FRAMEWORK_VERSION;
}

- (NSString *)readVendorName {
    return [NSString stringWithFormat:@"%s", vendor_name];
}

- (void)readValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral {
    CBService *service = [self findServiceFromUUID:serviceUUID peripheral:peripheral];
    
    if (!service) {
        NSLog(@"Could not find service with UUID %s on peripheral with UUID %@",[self CBUUIDToString:serviceUUID],[self UUIDToString:peripheral.identifier]);
        return;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic)
    {
        NSLog(@"Could not find characteristic with UUID %s on service with UUID %s on peripheral with UUID %@",
              [self CBUUIDToString:characteristicUUID], [self CBUUIDToString:serviceUUID], [self UUIDToString:peripheral.identifier]);
        return;
    }
    
    [peripheral readValueForCharacteristic:characteristic];
}

- (void)writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID peripheral:(CBPeripheral *)peripheral data:(NSData *)data {
    CBService *service = [self findServiceFromUUID:serviceUUID peripheral:peripheral];
    
    if (!service)
    {
        NSLog(@"Could not find service with UUID %s on peripheral with UUID %@",
              [self CBUUIDToString:serviceUUID], [self UUIDToString:peripheral.identifier]);
        return;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic)
    {
        NSLog(@"Could not find characteristic with UUID %s on service with UUID %s on peripheral with UUID %@",
              [self CBUUIDToString:characteristicUUID], [self CBUUIDToString:serviceUUID], [self UUIDToString:peripheral.identifier]);
        return;
    }
    
    [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
}

- (UInt16)swap:(UInt16)s {
    UInt16 temp = s << 8;
    temp |= (s >> 8);
    return temp;
}

// Step 1
- (int)controlSetup:(int)s {
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    return 0;
}

// Step 2
- (int)findBLEPeripherals:(int)timeout {
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"CoreBluetooth not correctly initialized !");
        NSLog(@"State = %d (%s)", self.centralManager.state,[self centralManagerStateToString:self.centralManager.state]);
        return -1;
    }
    
    [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
    
#if TARGET_OS_IPHONE
    [self.centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID]] options:nil];
#else
    [self.centralManager scanForPeripheralsWithServices:nil options:nil]; // Start scanning
#endif
    
    NSLog(@"scanForPeripheralsWithServices");
    
    return 0; // Started scanning OK !
}

// Step 4
- (void)connectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connecting to peripheral with UUID : %@", [self UUIDToString:peripheral.identifier]);
    
    self.activePeripheral = peripheral;
    self.activePeripheral.delegate = self;
    [self.centralManager connectPeripheral:self.activePeripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}

- (const char *)centralManagerStateToString:(int)state {
    switch(state) {
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    
    return "Unknown state";
}

- (void)scanTimer:(NSTimer *)timer {
    [self.centralManager stopScan];
    NSLog(@"Stopped Scanning");
    NSLog(@"Known peripherals : %d", [self.peripherals count]);
    [self printKnownPeripherals];
}

- (void)printKnownPeripherals {
    int i;
    
    NSLog(@"List of currently known peripherals: ");
    
    for (i = 0; i < self.peripherals.count; i++)
    {
        CBPeripheral *peripheral = [self.peripherals objectAtIndex:i];
        
        if (peripheral.identifier != nil)
        {
            NSLog(@"%d  |  %@", i, [self UUIDToString:peripheral.identifier]);
        }
        else
            NSLog(@"%d  |  NULL",i);
        
        [self printPeripheralInfo:peripheral];
    }
}

- (void)printPeripheralInfo:(CBPeripheral*)peripheral {
    NSLog(@"------------------------------------");
    NSLog(@"Peripheral Info :");
    
    if (peripheral.identifier != nil)
    {
        NSLog(@"UUID : %@", [self UUIDToString:peripheral.identifier]);
    }
    else
        NSLog(@"UUID : NULL");
    
    NSLog(@"Name : %s",[peripheral.name cStringUsingEncoding:NSStringEncodingConversionAllowLossy]);
    NSLog(@"-------------------------------------");
}

- (BOOL)UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUDID2 {

    if ([UUID1.UUIDString isEqualToString:UUDID2.UUIDString]) {
        return YES;
    }
    
    return NO;
}

- (void)getAllServicesFromPeripheral:(CBPeripheral *)peripheral {
    [peripheral discoverServices:nil]; // Discover all services without filter
}

- (void)getAllCharacteristicsFromPeripheral:(CBPeripheral *)peripheral {
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (const char *)CBUUIDToString:(CBUUID *) UUID {
    return [[UUID.data description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy];
}

- (NSString *)UUIDToString:(NSUUID *)UUID {
    if (!UUID)
        return @"NULL";
    
    return UUID.UUIDString;
}


- (BOOL)compareCBUUID:(CBUUID *)UUID1 UUID2:(CBUUID *)UUID2 {
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1];
    [UUID2.data getBytes:b2];
    if (memcmp(b1, b2, UUID1.data.length) == 0)return YES;
    else return NO;
}


- (BOOL)compareCBUUIDToInt:(CBUUID *)UUID1 UUID2:(UInt16)UUID2 {
    char b1[16];
    
    [UUID1.data getBytes:b1];
    UInt16 b2 = [self swap:UUID2];
    
    if (memcmp(b1, (char *)&b2, 2) == 0)
        return YES;
    else
        return NO;
}

- (UInt16)CBUUIDToInt:(CBUUID *)UUID {
    char b1[16];
    [UUID.data getBytes:b1];
    return ((b1[0] << 8) | b1[1]);
}

//- (CBUUID *)IntToCBUUID:(UInt16)UUID {
//    char t[16];
//    t[0] = ((UUID >> 8) & 0xff); t[1] = (UUID & 0xff);
//    NSData *data = [[NSData alloc] initWithBytes:t length:16];
//    return [CBUUID UUIDWithData:data];
//}

- (CBService *)findServiceFromUUID:(CBUUID *)UUID peripheral:(CBPeripheral *)peripheral {
    for(int i = 0; i < peripheral.services.count; i++) {
        CBService *service = [peripheral.services objectAtIndex:i];
        if ([self compareCBUUID:service.UUID UUID2:UUID]) return service;
    }
    
    return nil; //Service not found on this peripheral
}

- (CBCharacteristic *)findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    for(int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) return c;
    }
    
    return nil; //Characteristic not found on this service
}

#if TARGET_OS_IPHONE
    //-- no need for iOS
#else
- (BOOL)isLECapableHardware {
    NSString * state = nil;
    
    switch ([centralManager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
            
    }
    
    NSLog(@"Central manager state: %@", state);
        
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert setIcon:[[NSImage alloc] initWithContentsOfFile:@"AppIcon"]];
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:nil contextInfo:nil];
    return FALSE;
}
#endif


#pragma mark -
#pragma mark - CBCentralManagerDelegate methods


// Step 3
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSLog(@"didDiscoverPeripheral");
    [self connectPeripheral:peripheral];
    
    if (!self.peripherals) {
        self.peripherals = [[NSMutableArray alloc] initWithObjects:peripheral,nil];
    } else {
        for(int i = 0; i < self.peripherals.count; i++)
        {
            CBPeripheral *p = [self.peripherals objectAtIndex:i];
            
            if ((p.identifier == nil) || (peripheral.identifier == nil))
                continue;
            
            if ([self UUIDSAreEqual:p.identifier UUID2:peripheral.identifier]) {
                [self.peripherals replaceObjectAtIndex:i withObject:peripheral];
                NSLog(@"Duplicate UUID found updating...");
                return;
            }
        }
        
        [self.peripherals addObject:peripheral];
        
        NSLog(@"New UUID, adding");
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
#if TARGET_OS_IPHONE
    NSLog(@"Status of CoreBluetooth central manager changed %d (%s)", central.state, [self centralManagerStateToString:central.state]);
#else
    [self isLECapableHardware];
#endif
}

// Step 5
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (peripheral.identifier != nil)
        NSLog(@"Connected to %@ successful",[self UUIDToString:peripheral.identifier]);
    else
        NSLog(@"Connected to NULL successful");
    self.activePeripheral = peripheral;

    [self.activePeripheral discoverServices:nil];
    [self getAllServicesFromPeripheral:peripheral];
}


static bool done = false;

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    done = false;
    
    [[self delegate] BLEDidDisconnect];
    
    isConnected = false;
}


#pragma mark -
#pragma mark - CBPeripheralDelegate methods

// Step 6
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (!error) {
        NSLog(@"Services of peripheral with UUID : %@ found.",[self UUIDToString:peripheral.identifier]);
        [self getAllCharacteristicsFromPeripheral:peripheral];
    }
    else {
        NSLog(@"Service discovery was unsuccessful!");
    }
}

// Step 7
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {

    if (error) {
        NSLog(@"Error didDiscoverCharacteristicsForService: %@", error);
    } else {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID]]) {
            
            for (CBCharacteristic *characteristic in service.characteristics) {
                
                NSLog(@"Found characteristic %s", [self CBUUIDToString:characteristic.UUID]);
                
                CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
                
                if ([service.UUID isEqual:s.UUID]) {
                    if (!done) {
                        [self enableReadNotification:_activePeripheral];
                        [self readLibVerFromPeripheral];
                        [self readVendorNameFromPeripheral];
                        
                        [[self delegate] BLEDidConnect];
                        
                        isConnected = true;
                        [_activePeripheral readRSSI];
                        
                        done = true;
                    }
                    
                    break;
                }
            }
        }
    }
}

// Step 8
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    unsigned char data[BLE_DEVICE_RX_READ_LEN];
    
    static unsigned char buf[512];
    static int len = 0;
    int data_len;
    
    if (!error) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@BLE_DEVICE_RX_UUID]]) {
            data_len = characteristic.value.length;
            [characteristic.value getBytes:data length:data_len];
            
            if (data_len == 20) {
                memcpy(&buf[len], data, 20);
                len += data_len;
                
                if (len >= 64)
                {
                    [[self delegate] BLEDidReceiveData:buf length:len];
                    len = 0;
                }
            } else if (data_len < 20) {
                memcpy(&buf[len], data, data_len);
                len += data_len;
                
                [[self delegate] BLEDidReceiveData:buf length:len];
                len = 0;
            }
            
            [self enableWrite];
        }
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@BLE_DEVICE_VENDOR_NAME_UUID]]) {
            data_len = characteristic.value.length;
            [characteristic.value getBytes:vendor_name length:data_len];
            NSLog(@"Vendor: %s", vendor_name);
        }
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@BLE_DEVICE_LIB_VERSION_UUID]]) {
            [characteristic.value getBytes:&libver length:2];
            NSLog(@"Lib. ver.: %X", libver);
        }
    } else {
        NSLog(@"updateValueForCharacteristic failed!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (!error) {
        NSLog(@"Updated notification state for characteristic with UUID %s on service with  UUID %s on peripheral with UUID %@", [self CBUUIDToString:characteristic.UUID], [self CBUUIDToString:characteristic.service.UUID], [self UUIDToString:peripheral.identifier]);
    }
    else {
        NSLog(@"Error in setting notification state for characteristic with UUID %s on service with  UUID %s on peripheral with UUID %@",
              [self CBUUIDToString:characteristic.UUID], [self CBUUIDToString:characteristic.service.UUID], [self UUIDToString:peripheral.identifier]);
        NSLog(@"Error code was %s",[[error description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy]);
    }
}


- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error {
    if (!isConnected)
        return;
    
    if (rssi != peripheral.RSSI.intValue) {
        rssi = peripheral.RSSI.intValue;
        [[self delegate] BLEDidUpdateRSSI:_activePeripheral.RSSI];
    }
    [_activePeripheral readRSSI];
}

@end
