//
//  DocumentBrowserViewController.swift
//  doc test
//
//  Created by Toby Harris on 27/11/2019.
//  Copyright © 2019 Toby Harris. All rights reserved.
//

import UIKit

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        
        // Update the style of the UIDocumentBrowserViewController
        // browserUserInterfaceStyle = .dark
        // view.tintColor = .white
        
        // Specify the allowed content types of your application via the Info.plist.
        
        // Do any additional setup after loading the view.
    }
    
    
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        guard let tempURL = try? Settings.urlCacheDoc() else {
            let alertController = UIAlertController(title: "Cannot create document", message: "Could not access storage", preferredStyle: .alert)
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        let document = Document(fileURL: tempURL)
        document.save(to: tempURL, for: .forCreating) { (saveSuccess) in
            // Make sure the document saved successfully
            guard saveSuccess else {
                // Cancel document creation
                importHandler(nil, .none)
                return
            }

            // Close the document.
            document.close(completionHandler: { (closeSuccess) in
               
                // Make sure the document closed successfully
                guard closeSuccess else {
                    // Cancel document creation
                    importHandler(nil, .none)
                    return
                }
                
                // Pass the document's temporary URL to the import handler.
                importHandler(tempURL, .move)
            })
        }
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }
        
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
    }
    
    // MARK: Document Presentation
    
    func presentDocument(at documentURL: URL) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let documentViewController = storyBoard.instantiateViewController(withIdentifier: "DocumentViewController") as! DocumentViewController
        documentViewController.document = Document(fileURL: documentURL)
        documentViewController.modalPresentationStyle = .fullScreen
        
        present(documentViewController, animated: true, completion: nil)
    }
}

