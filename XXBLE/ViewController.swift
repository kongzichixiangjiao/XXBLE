//
//  ViewController.swift
//  XXBLE
//
//  Created by 侯佳男 on 2017/8/10.
//  Copyright © 2017年 侯佳男. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {

    @IBOutlet weak var bleStateLabel: UILabel!
    @IBOutlet weak var contactLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    var manager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var characteristic: CBCharacteristic!
    
    var equipmentArray: [CBPeripheral] = []
    var lastString: String = ""
    var sendString: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func disconnect(_ sender: Any) {
        guard let peripheral = connectedPeripheral else {
            return
        }
        manager.cancelPeripheralConnection(peripheral)
    }
    
    @IBAction func scanAction(_ sender: UIButton) {
        equipmentArray.removeAll()
        tableView.reloadData()
        manager.scanForPeripherals(withServices: nil, options: nil)
    }

    @IBAction func writeAction(_ sender: UIButton) {
        let data = "8888888".data(using: .utf8)
        viewController(self.connectedPeripheral, didWriteValueFor: self.characteristic, value: data!)
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var text: String = ""
        switch central.state {
        case .unknown:
            text = "unknown"
        case .resetting:
            text = "resetting"
        case .unsupported:
            text = "unsupported"
        case .unauthorized:
            text = "unauthorized"
        case .poweredOff:
            text = "poweredOff"
        case .poweredOn:
            text = "poweredOn"
        }
        bleStateLabel.text = text
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("central == \(central)")
        print("dict == \(dict)")
        contactLabel.text = "将要连接"
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("central == \(central), didConnnect == \(peripheral)")
        contactLabel.text = "连接成功"
        connectedPeripheral = peripheral
        //外设寻找service
        peripheral .discoverServices(nil)
        
        peripheral.delegate = self
        self.title = peripheral.name
        manager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        contactLabel.text = "连接失败"
        print("central == \(central)")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("central == \(central)")
        contactLabel.text = "断开连接"
    }
    
    // 找到设备调用方法
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("central == \(central)")
        print("advertisementData: \(advertisementData)")
        /*
         ["kCBAdvDataIsConnectable": 1, "kCBAdvDataLocalName": Moving Heart, "kCBAdvDataManufacturerData": <47170101 17ccc42f df8596>, "kCBAdvDataServiceUUIDs": <__NSArrayM 0x174248400>(
         0AF0,
         FEE7,
         Heart Rate
         )
         ]
         */
        
        contactLabel.text = "正在查询"
        
        guard let name = peripheral.name else {
            return
        }
        
        if name != "" {
            //找到的设备必须持有它，否则CBCentralManager中也不会保存peripheral，那么CBPeripheralDelegate中的方法也不会被调用！！
            equipmentArray.append(peripheral)
            self.tableView.reloadData()
        }
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print(peripheral, error ?? "error nil")
        if (error != nil){
            print("查找 services 时 \(String(describing: peripheral.name)) 报错 \(String(describing: error?.localizedDescription))")
        }
        for service in peripheral.services! {
            //需要连接的 CBCharacteristic 的 UUID
            if service.uuid.uuidString == "0AF0" {
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid.uuidString == "0AF6" {
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid.uuidString == "0AF2" {
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid.uuidString == "0AF1" {
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid.uuidString == "0AF7" {
                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                
            }
            
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?){
        if error != nil{
            print("查找 characteristics 时 \(String(describing: peripheral.name)) 报错 \(String(describing: error?.localizedDescription))")
        }
        //获取Characteristic的值，读到数据会进入方法：
        for characteristic in service.characteristics! {
            peripheral.readValue(for: characteristic)
            
            //设置 characteristic 的 notifying 属性 为 true ， 表示接受广播
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    //获取外设发来的数据，不论是read和notify,获取数据都是从这个方法中读取。
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?){
        let resultStr = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue)
        
        print("characteristic uuid:\(characteristic.uuid) value:\(String(describing: resultStr))")
        print("characteristic.value: \(String(describing: characteristic.value))")
        if lastString == resultStr! as String {
            return
        }
        
        // 操作的characteristic 保存
        self.characteristic = characteristic
    }
    
    //写数据方法如下，需要把它加到需要的位置
    func viewController(_ peripheral: CBPeripheral,didWriteValueFor characteristic: CBCharacteristic,value : Data ) -> () {
        
        //只有 characteristic.properties 有write的权限才可以写入
        if characteristic.properties.contains(CBCharacteristicProperties.write){
            //设置为  写入有反馈
            self.connectedPeripheral.writeValue(value, for: characteristic, type: .withResponse)
        }else{
            print("写入不可用~")
        }
    }
    // 用于检测中心向外设写数据是否成功
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?){
        if error != nil{
            print("写入 characteristics 时 \(String(describing: peripheral.name)) 报错 \(String(describing: error?.localizedDescription))")
        }
        
        let alertView = UIAlertController.init(title: "抱歉", message: "写入成功", preferredStyle: UIAlertControllerStyle.alert)
        let cancelAction = UIAlertAction.init(title: "好的", style: .cancel, handler: nil)
        alertView.addAction(cancelAction)
        alertView.show(self, sender: nil)
        lastString = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue)! as String
    }
    
    //中心读取外设实时数据
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        if let e = error {
            print("error: \(e)")
            return
        }
        
        // Notification has started
        if (characteristic.isNotifying) {
            peripheral.readValue(for: characteristic)
        } else { // Notification has stopped
            // so disconnect from the peripheral
            print(characteristic)
            self.manager.cancelPeripheralConnection(self.connectedPeripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("didDiscoverDescriptorsFor")
    }


}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        let peripheral: CBPeripheral = equipmentArray[indexPath.row]
        cell?.textLabel?.text = peripheral.name ?? "--"
        return cell!
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return equipmentArray.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral: CBPeripheral = equipmentArray[indexPath.row]
        manager.connect(peripheral, options: nil)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


