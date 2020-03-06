//
//  ViewController.swift
//  SportsMan
//
//  Created by Alexander Gurzhiev on 17/08/2019.
//  Copyright © 2019 Alexander Gurzhiev. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let containter = (UIApplication.shared.delegate as! AppDelegate).persistentContainer
        context = containter.viewContext
        context.mergePolicy = NSOverwriteMergePolicy
        backgroundContext = containter.newBackgroundContext()
        setupFetchedResultsController()
        NotificationCenter.default.addObserver(self, selector: #selector(managedObjectContextDidSave(notification:)),
                                               name: .NSManagedObjectContextDidSave, object: nil)
    }
    
    @objc func managedObjectContextDidSave(notification: Notification) {
        context.perform { [weak self] in
            self?.context.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    private var context: NSManagedObjectContext!
    private var backgroundContext: NSManagedObjectContext!
    private var fetchedResultsController: NSFetchedResultsController<Circle>?
    private func setupFetchedResultsController() {
        let sortDescriptor = NSSortDescriptor(key: "time", ascending: true)
        let request = NSFetchRequest<Circle>(entityName: "Circle")
        request.sortDescriptors = [ sortDescriptor ]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request,
                                                              managedObjectContext: context,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController?.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
        } catch (let error) {
            print(error.localizedDescription)
        }
    }

    private var time: TimeInterval = 0
    private var timer: Timer?
    private func runTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] (timer) in
            self?.time += 0.01
        })
        guard let timer = timer else { return }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @IBAction func triggerTapepd(_ sender: UIButton) {
        if timer == nil { // start
            title = "Время пошло"
            sender.isSelected = true
            
            runTimer()
        } else { // stop
            title = "Результаты"
            sender.isSelected = false
            
            timer?.invalidate()
            timer = nil
            time = 0
        }
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        guard let backgroundContext = backgroundContext else { return }
        guard time > 0 else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            let newCircle = Circle(context: backgroundContext)
            newCircle.time = self.time
            
            guard backgroundContext.hasChanges else { return }
            backgroundContext.performAndWait {
                do {
                    try backgroundContext.save()
                } catch (let error) {
                    print(error.localizedDescription)
                }
            }
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let sectionsCount = fetchedResultsController?.sections?.count else { return 0 }
        return sectionsCount
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let objects = fetchedResultsController?.fetchedObjects else { return 0 }
        return objects.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        guard let circle = fetchedResultsController?.object(at: indexPath) else { return cell }
        
        cell.textLabel?.text = circle.time.stringFromTimeInterval()
        return cell
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let newIndexPath = newIndexPath else { return }
        if type == .insert {
            tableView.insertRows(at: [newIndexPath], with: .left)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}

extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let time = NSInteger(self)
        
        let ms = Int((self.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = time % 60
        let minutes = (time / 60) % 60
        
        return String(format: "%0.2d:%0.2d.%0.3d",minutes,seconds,ms)
    }
}
