//
//  ViewController.swift
//  blueMarc
//
//  Created by Tomas Vega on 12/7/17.
//  Copyright © 2017 Tomas Vega. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController,
                      CBCentralManagerDelegate,
                      CBPeripheralDelegate {
  
  var manager:CBCentralManager!
  var _peripheral:CBPeripheral!
  var sendCharacteristic: CBCharacteristic!
  var loadedService: Bool = true
  
  let NAME = "RFduino"
  let UUID_SERVICE = CBUUID(string: "2220")
  let UUID_READ = CBUUID(string: "2221")
  let UUID_WRITE = CBUUID(string: "2222")
  
  @IBOutlet weak var stateInput: UISwitch!
  @IBOutlet weak var modeInput: UISegmentedControl!
  @IBOutlet weak var powerInput: UISlider!

  
  var stateValue: Bool = false
  var modeValue: Int = 0
  var powerValue: Int = 0
  
  func getData() -> NSData{
    let state: UInt8 = stateValue ? 1 : 0
    let mode: UInt8 = UInt8(modeValue)
    let power:UInt8 = UInt8(powerValue)
    var theData : [UInt8] = [ state, mode, power ]
    print(theData)
    let data = NSData(bytes: &theData, length: theData.count)
    return data
  }
  

  func updateSettings() {
    if loadedService {
      if _peripheral?.state == CBPeripheralState.connected {
        if let characteristic:CBCharacteristic? = sendCharacteristic{
          let data: Data = getData() as Data
          _peripheral?.writeValue(data,
                                  for: characteristic!,
                                  type: CBCharacteristicWriteType.withResponse)
        }
      }
    }
  }
  
  @IBAction func stateChanged(_ sender: UISwitch) {
    print("STATE CHANGED")
    stateValue = stateInput.isOn
    print(stateValue)
    if !stateValue {
      powerInput.isEnabled = false
      powerInput.tintColor = UIColor .gray
      enableModeInput(false)
    } else {
      powerInput.isEnabled = true
      powerInput.tintColor = modeValue == 0 ? UIColor .red : UIColor .blue
      modeInput.selectedSegmentIndex = modeValue
      enableModeInput(true)
    }
    updateSettings()
  }
  
  @IBAction func modeChanged(_ sender: UISegmentedControl) {
    print("MODE CHANGED")
    modeValue = modeInput.selectedSegmentIndex
    print(modeValue)
    if modeValue == 0 {
      powerInput.tintColor = UIColor .red
    } else {
      powerInput.tintColor = UIColor .blue
    }
    updateSettings()
  }
  
  @IBAction func powerChanged(_ sender: UISlider) {
    powerValue = Int(powerInput.value*100)
    updateSettings()
  }

  
  func enableModeInput(_ enable: Bool) {
    if (enable) {
      modeInput.setEnabled(true, forSegmentAt: 0)
      modeInput.setEnabled(true, forSegmentAt: 1)
    } else {
      modeInput.setEnabled(false, forSegmentAt: 0)
      modeInput.setEnabled(false, forSegmentAt: 1)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    manager = CBCentralManager(delegate: self, queue: nil)
    stateInput.setOn(false, animated: false)
    enableModeInput(false)
    powerInput.isEnabled = false
    powerInput.value = 0.0
    powerInput.isContinuous = false;
    
    // Do any additional setup after loading the view, typically from a nib.
    stateValue = stateInput.isOn
    modeValue = 0
    powerValue = 0
    
    let hotSegment = modeInput.subviews[0] as UIView
    let coldSegment = modeInput.subviews[1] as UIView
    hotSegment.tintColor = UIColor .red
    coldSegment.tintColor = UIColor .blue
    powerInput.tintColor = UIColor .gray
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == CBManagerState.poweredOn {
      print("Buscando a Marc")
      central.scanForPeripherals(withServices: nil, options: nil)
    }
  }
  
  // Found a peripheral
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//    print("found a peripheral")
    // Device
    let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
    // Check if this is the device we want
    if device?.contains(NAME) == true {

      // Stop looking for devices
      // Track as connected peripheral
      // Setup delegate for events
      self.manager.stopScan()
      self._peripheral = peripheral
      self._peripheral.delegate = self
      
      // Connect to the perhipheral proper
      manager.connect(peripheral, options: nil)
      
      // Debug
      debugPrint("Found Bean.")
    }
  }
  
  // Connected to peripheral
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // Ask for services
    peripheral.discoverServices(nil)
    
    // Debug
    debugPrint("Getting services ...")
  }
  
  // Discovered peripheral services
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    // Look through the service list
    for service in peripheral.services! {
      let thisService = service as CBService
      
      // If this is the service we want
      print(service.uuid)
      if service.uuid == UUID_SERVICE {
        // Ask for specific characteristics
        peripheral.discoverCharacteristics(nil, for: thisService)
        
        // Debug
        debugPrint("Using scratch.")
      }
      
      // Debug
      debugPrint("Service: ", service.uuid)
    }
  }
  
  // Discovered peripheral characteristics
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    debugPrint("Enabling ...")
    
    // Look at provided characteristics
    for characteristic in service.characteristics! {
      let thisCharacteristic = characteristic as CBCharacteristic
      
      // If this is the characteristic we want
      print(thisCharacteristic.uuid)
      if thisCharacteristic.uuid == UUID_READ {
        // Start listening for updates
        // Potentially show interface
        self._peripheral.setNotifyValue(true, for: thisCharacteristic)
        
        // Debug
        debugPrint("Set to notify: ", thisCharacteristic.uuid)
      } else if thisCharacteristic.uuid == UUID_WRITE {
        sendCharacteristic = thisCharacteristic
        loadedService = true
      }
      
      // Debug
      debugPrint("Characteristic: ", thisCharacteristic.uuid)
    }
  }
  
  // Data arrived from peripheral
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    print("Data")
    // Make sure it is the peripheral we want
    print(characteristic.uuid)
    if characteristic.uuid == UUID_READ {
      // Get bytes into string
      let dataReceived = characteristic.value! as NSData
      var out1: UInt32 = 0
      var out2: UInt32 = 0
      var out3: UInt32 = 0
      dataReceived.getBytes(&out1, range: NSRange(location: 0, length: 4))
      dataReceived.getBytes(&out2, range: NSRange(location: 4, length: 4))
      dataReceived.getBytes(&out3, range: NSRange(location: 8, length: 4))
      print(out1)
      print(out2)
      print(out3)
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    print("success")
    print(characteristic.uuid)
    print(error)
  }
  
  // Peripheral disconnected
  // Potentially hide relevant interface
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    debugPrint("Disconnected.")
    
    // Start scanning again
    central.scanForPeripherals(withServices: nil, options: nil)
  }

}

