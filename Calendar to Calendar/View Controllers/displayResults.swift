//
//  displayResults.swift
//  QuickstartApp
//
//  Created by Jack Rosen on 1/18/18.
//  Copyright © 2018 Jack Rosen. All rights reserved.
//

import UIKit
import EventKit

class customcell: UITableViewCell{
    @IBOutlet weak var nameOfEvent: UITextView!
    @IBOutlet weak var startDate: UILabel!
    @IBOutlet weak var endDate: UILabel!
    @IBOutlet weak var alarmPicker: UIPickerView!
}
class displayResults: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, UITextViewDelegate {
    
    //Calls all of the variables
    private var alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
    private let alarmPickerDate:[String] = ["No Alarm", "5 Minutes Before", "15 Minutes Before", "30 Minutes Before", "1 Hour Before", "2 Hours Before", "6 Hours Before", "1 Day Before", "2 Days Before", "1 Week Before"]
    @IBOutlet weak var tableView: UITableView!
    private let store = EKEventStore()
    var events: [Event] = [Event]()
    private var incorrect = 0
    private var wrongEvents = [Event]()
    //Test: ca-app-pub-3940256099942544/4411468910
    //Production: ca-app-pub-1472286068235914/8440163507
    private var activity = UIActivityIndicatorView(style: .gray)
    private var adState: LoadState = .began
	var holder: HoldingController?
    override func viewDidLoad() {
        self.activity.stopAnimating()
        createDismissedKeyboard()
        super.viewDidLoad()
        setUpTableView()
        //Only show the alert the first time it is downloaded. Else, there is no need to keep showing it
        if (UserDefaults.standard.integer(forKey: "Version") < 2) {
            showAlert(title: "Hint:", message: "Click on the name of the event to change it!"){ _ in
                    self.showIncorrectEvents()
                }
        }
    }

	private func setUpTableView(){
        //Displays the table view
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = 200
        self.tableView.separatorStyle = .singleLine
        self.tableView.separatorColor = UIColor.black
        self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    @IBAction func signOut(_ sender: Any) {
		self.holder?.signOut(from: self)
    }
	@IBAction func sendBackToChoose(_ sender: Any) {
		if let vc = storyboard?.instantiateViewController(withIdentifier: "chooseOption") as? ChooseExport {
			vc.holder = self.holder
			self.holder?.transition(from: self, to: vc, with: .leftToRight)
		}
	}
	
    //When it stops editing, puts information into events
    func textViewDidEndEditing(_ textView: UITextView)
    {
        changeText(events[Int(textView.restorationIdentifier!)!], name:textView.text)
        tableView.tableFooterView = UIView()
        let indexPath = IndexPath(row: Int(textView.restorationIdentifier!)!, section: 0)
        UIView.animate(withDuration: 0.6, animations: {
            [unowned self] in
            if (indexPath.row == self.events.count - 1)
            {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            }
            else if (indexPath.row != 0){
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
            }}, completion: nil)
        tableView.isScrollEnabled = true
    }
    //Changes the name of the event
    func changeText(_ event: Event, name: String){
        if let index = self.events.firstIndex(of: event){
            events[index].name = name
        }
    }
    //Gets rid of keyboard on enter
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    //Moves text so it is visible
    func textViewDidBeginEditing(_ textView: UITextView)
    {
        let rect = CGRect(x: 0, y: 0, width: tableView.frame.width, height: tableView.frame.height)
        tableView.tableFooterView = UIView(frame: rect)
        let indexPath = IndexPath(row: Int(textView.restorationIdentifier!)!, section: 0)
        UIView.animate(withDuration: 0.6, animations: {
            [weak self] in
            self?.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            }, completion: nil)
        tableView.isScrollEnabled = false
    }
    //Picker View functions
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return alarmPickerDate.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return alarmPickerDate[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        if let identifier = pickerView.restorationIdentifier
        {
            changeAlarm(events[Int(identifier)!], alarm: row)
        }
    }
    private func changeAlarm(_ event: Event, alarm: Int){
        if let index = events.firstIndex(of: event){
            events[index].alarm = alarm
            if let cell = tableView.cellForRow(at: IndexPath(item: index, section: 0)){
                (cell as! customcell).alarmPicker.selectRow(alarm, inComponent: 0, animated: true)
            }
        }
    }
    //Changes the Alarm for each event
    @IBAction func fullAlarmChange(_ sender: Any) {
        DispatchQueue.main.async(execute: {
            let alert = UIAlertController(title: "How long before would you want an alarm for?", message: "This is for all events.", preferredStyle: .alert)
			let height:NSLayoutConstraint = NSLayoutConstraint(item: alert.view ?? UIView(frame: CGRect.zero), attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 300)
            alert.view.addConstraint(height);
            let pickerFrame: CGRect = CGRect(x: 0, y: 100, width: 270, height: 100);
            let picker: UIPickerView = UIPickerView(frame: pickerFrame);
            picker.delegate = self
            picker.dataSource = self
            alert.view.addSubview(picker)
            let action1 = UIAlertAction(title: "Select", style: .default, handler: { (action) -> Void in
                let checker = picker.selectedRow(inComponent: 0)
                for counter in 0 ..< self.events.count
                {
                    self.changeAlarm(self.events[counter], alarm: checker)
                }
            })
            let action2 = UIAlertAction(title: "Cancel", style: .default, handler: {(action) -> Void in})
            alert.addAction(action2)
            alert.addAction(action1)
            self.present(alert, animated: true, completion: nil)
        })
    }
    //Changes the name of all events
    @IBAction func changeAll(_ sender: Any) {
        DispatchQueue.main.async(execute: {
            self.alert = UIAlertController(title: "What would you like the name to be?", message: "", preferredStyle: .alert)
            self.alert.addTextField { (textField: UITextField) in
                textField.keyboardAppearance = .light
                textField.keyboardType = .default
                textField.placeholder = "Event Name"
                textField.textColor = UIColor.black
                textField.autocapitalizationType = UITextAutocapitalizationType.sentences
            }
            let action1 = UIAlertAction(title: "Rename", style: .default, handler: { (action) -> Void in
                for counter in 0 ... self.events.count - 1
                {
                    self.events[counter].name = self.alert.textFields![0].text!
                }
                for cell in self.tableView.visibleCells as! Array<customcell>
                {
                    cell.nameOfEvent.text = self.alert.textFields![0].text!
                }
            })
            let action2 = UIAlertAction(title: "Cancel", style: .default, handler: nil)
            self.alert.addAction(action2)
            self.alert.addAction(action1)
            self.present(self.alert, animated: true, completion: nil)
        })
    }
    // number of rows in table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.events.count
    }
    //Cell was selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showAlert(title: "Your event", message: events[indexPath.row].description)
        
    }
    // create a cell for each table view row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // create a new cell if needed or reuse an old one
        let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell") as! customcell
        let event = events[indexPath.row]
        cell.contentView.backgroundColor = UIColor.white
        cell.sizeToFit()
        cell.nameOfEvent.delegate = self
        cell.nameOfEvent.text = event.name
        cell.nameOfEvent.allowsEditingTextAttributes = true
        if (event.isAllDay)
        {
            cell.startDate.text = event.formattedStartDate
            cell.endDate.text = "All Day"
        }
        else
        {
            cell.startDate.text = "Start: \(event.formattedStartDate)"
            cell.endDate.text = "End: \(event.formattedEndDate)"
        }
        cell.alarmPicker.dataSource = self
        cell.alarmPicker.delegate = self
        cell.alarmPicker.reloadAllComponents()
        cell.alarmPicker.selectRow(event.alarm, inComponent: 0, animated: false)
        cell.alarmPicker.restorationIdentifier = String(describing: indexPath.row)
        cell.nameOfEvent.restorationIdentifier = String(describing: indexPath.row)
        if (indexPath.row < incorrect){
            cell.layer.borderColor = UIColor.red.cgColor
            cell.layer.borderWidth = 2
        }
        else{
            cell.layer.borderWidth = 0
            cell.layer.borderColor = UIColor.clear.cgColor
        }
        return cell
    }
    //Method to Remove an Event
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let info = events.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.none)
            if let index = events.firstIndex(of: info){
                events.remove(at: index)
                tableView.deleteRows(at: [IndexPath(item: Int(index), section: 0)], with: .none)
                incorrect -= 1
            }
            if (events.count == 0)
            {
                DispatchQueue.main.async(execute: {
                    self.showAlert(title: "You have no events chosen.", message: ""){(action) -> Void in
                        self.segueBack()
                    }
                })
                
            }else {
                guard let cells = tableView.visibleCells as? [customcell] else {return}
                for cell in cells
                {
                    let indexPath: IndexPath = tableView.indexPath(for: cell)!
                    cell.alarmPicker.restorationIdentifier = String(describing: indexPath.row)
                    cell.nameOfEvent.restorationIdentifier = String(describing: indexPath.row)
                    if (indexPath.row < incorrect){
                        cell.layer.borderWidth = 2
                        cell.layer.borderColor = UIColor.red.cgColor
                    }
                    else{
                        cell.layer.borderWidth = 0
                        cell.layer.borderColor = UIColor.clear.cgColor
                    }
                }
            }
        }
    }
    private func getDayOfWeek(date: String) -> (String, Int)
    {
        let calendar: Foundation.Calendar = Foundation.Calendar(identifier: Foundation.Calendar.Identifier.gregorian)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        let dateDate = dateFormatter.date(from: date)!
        let dayOfWeek = calendar.component(.weekday, from: dateDate)
        return (dateFormatter.weekdaySymbols[dayOfWeek - 1], dayOfWeek)
    }
    //Displays advertisement
    @IBAction func addEvents(_ sender: Any) {
		DispatchQueue.main.async {
			self.formatEvents()
		}
	}
    //Formats events to prepare for putting it into calendar
    func formatEvents()
    {
        for counter in 0 ..< events.count
        {
            var event = self.events[counter]
            switch event.alarm
            {
            case 1:
                event.alarm = -300
                break
            case 2:
                event.alarm = -900
                break
            case 3:
                event.alarm = -1800
                break
            case 4:
                event.alarm = -3600
                break
            case 5:
                event.alarm = -7200
                break
            case 6:
                event.alarm = -21600
                break
            case 7:
                event.alarm = -86400
                break
            case 8:
                event.alarm = -172800
                break
            case 9:
                event.alarm = -604800
                break
            default:
                 break
            }
            self.events[counter].alarm = event.alarm
        }
        addEventToCalendar(events: events)
    }
	
    //Adds events to calendar
    private func addEventToCalendar(events: [Event]) {
        let dateForCal = events[0].startDate
        var newEvents = [Event]()
        newEvents.append(contentsOf: events)
        newEvents.removeFirst(self.incorrect)
        let interval: TimeInterval = dateForCal.timeIntervalSinceReferenceDate
        store.requestAccess(to: .event) { (success, error) in
            guard error == nil else{
                self.showAlert(title: "Error", message: error!.localizedDescription)
                return
            }
            for event in newEvents {
                //Creates the event using the function in event struct
                let calendarEvent = event.createCalendarEvent(self.store)
                do {
                    //Stores the values in the calendar
                    try self.store.save(calendarEvent, span: .thisEvent)
                    //event created successfullt to default calendar
                } catch let error {
                    self.showAlert(title: "Error", message: "Failed to save event with error : \(error.localizedDescription)")
                }
            }
            DispatchQueue.main.async(execute: {
                let alert = UIAlertController(title: "Events Were Created", message: "", preferredStyle: .alert)
                let action1 = UIAlertAction(title: "Go To Calendar", style: .default, handler: { (action) -> Void in
                    DispatchQueue.main.async{
                        let url = URL(string: "calshow:\(interval)")!
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        self.segueBack()
                    }
                })
                
                let action2 = UIAlertAction(title: "Ok", style: .default, handler: { (action) -> Void in
                    self.segueBack()
                })
                alert.addAction(action1)
                alert.addAction(action2)
                self.present(alert, animated: true, completion: nil)
            })
            
        }
    }
	
	/// Segues back to the choose export
	func segueBack() {
		if let vc = self.storyboard?.instantiateViewController(withIdentifier: "chooseOption") as? ChooseExport {
			vc.holder = self.holder
			self.holder?.transition(from: self, to: vc, with: .leftToRight)
		}
	}

	func sort(){
        DispatchQueue.global(qos: .userInitiated).async{
            var sorted = [(Int, Int)]()
            let stringFormatter = DateFormatter()
            stringFormatter.dateFormat = "MM/dd/yyyy"
            for event in self.events{
                sorted.append((self.getDayOfWeek(date: stringFormatter.string(from: event.startDate)).1, Foundation.Calendar.current.component(.hour, from: event.startDate)))
            }
            var added = 0
            var badEvents = [Event]()
            for counter in 1 ... 7{
                let filtered = sorted.filter({$0.0 == counter})
                if (filtered.count > 2)
                {
                    let index = self.returnIndices(events: filtered)
                    if (!index.isEmpty)
                    {
                        for counter in 0 ..< index.count{
                            if let eventIndex = sorted.firstIndex(where: {$0.0 == index[counter].0 && $0.1 == index[counter].1}){
                                badEvents.append(self.events[Int(eventIndex) + added])
                                added += 1
                                sorted.remove(at: eventIndex)
                            }
                        }
                    }
                }
            }
            if (added > 0)
            {
                self.wrongEvents = badEvents
                if UserDefaults.standard.integer(forKey: "Version") >= 2 {
                    self.showIncorrectEvents()
                }
            }
        }
    }
    func returnIndices(events: [(Int, Int)]) -> [(Int, Int)]
    {
        var intArray = [Int]()
        var returnArray = [(Int, Int)]()
        for counter in 0 ..< events.count{
            intArray.append(events.filter({$0.1 == events[counter].1}).count)
        }
        var array = intArray.filter({$0 == 1})
        if (array.count >= 1 && array.count <= events.count / 2)
        {
            while (!array.isEmpty){
                if let index = intArray.firstIndex(of: 1){
                    returnArray.append(events[index])
                    array.removeFirst()
                }
                
            }
        }
        return returnArray
    }
    func showIncorrectEvents(){
        if (self.wrongEvents.count != 0)
        {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Would you like to see suggestions of incorrect events?", message: nil, preferredStyle: UIAlertController.Style.alert)
                let yes = UIAlertAction(title: "Yes", style: .default, handler: {(action) -> Void in
                    self.events.insert(contentsOf: self.wrongEvents, at: 0)
                    self.incorrect = self.wrongEvents.count
                    self.tableView.reloadData()
                })
                let no = UIAlertAction(title: "No", style: .default, handler: nil)
                alert.addAction(no)
                alert.addAction(yes)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}
