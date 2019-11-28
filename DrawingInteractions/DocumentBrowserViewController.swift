//
//  DocumentBrowserViewController.swift
//  doc test
//
//  Created by Toby Harris on 27/11/2019.
//  Copyright © 2019 Toby Harris. All rights reserved.
//

import UIKit
import MobileCoreServices

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        
        allowsDocumentCreation = false
        allowsPickingMultipleItems = false
    }
        
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    // Ideally, this would get called when a video (i.e. not a document) is picked. However, currently to create a new document, the app also has videos as a document type, and so it "opens" a video.
    // So we do the import dance there, creating a document file in the document folder referencing the video.
    // Which is probably not the right way to do it, as e.g. we get "importHandler" here.
    // As a consequence this should never get called, as app is set to not create new documents.
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        guard let tempURL = try? Settings.urlCacheDoc() else {
            let alertController = UIAlertController(title: "Cannot create document", message: "Could not access storage", preferredStyle: .alert)
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        let document = Document(fileURL: tempURL)
        document.save(to: tempURL, for: .forCreating) { (saveSuccess) in
            guard saveSuccess else {
                // Cancel document creation
                importHandler(nil, .none)
                return
            }

            document.close(completionHandler: { (closeSuccess) in
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
        guard
            let sourceURL = documentURLs.first,
            let sourceUTI = try? sourceURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
        else {
            let alertController = UIAlertController(title: "Cannot open document", message: "Could not parse URL", preferredStyle: .alert)
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        // We are going to present `targetURL`. Default is the URL represents a DrawingInteractions document, so assign that here.
        var targetURL = sourceURL
        
        // If the URL represents a movie file, we need to create a new DrawingInteractions document.
        // Create it, assign it a new targetURL.
        // Set the document's movieURL property to the sourceURL.
        // ...Probably, ideally, this would be handled in "create new", see note at top.
        if UTTypeConformsTo(sourceUTI as NSString, "public.movie" as NSString) {
            guard
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            else {
                let alertController = UIAlertController(title: "Cannot import video", message: "Could not access documents folder", preferredStyle: .alert)
                self.present(alertController, animated: true, completion: nil)
                return
            }
            
            // Create new document URL, in the documents folder, using the movie's name as a base.
            let filename = sourceURL.deletingPathExtension().lastPathComponent
            targetURL = documentsURL.appendingPathComponent(Settings.filenameDocument(filename))
            if (try? targetURL.checkResourceIsReachable()) ?? false {
                let alertController = UIAlertController(title: "Cannot import video", message: "Document already exists: \(targetURL.lastPathComponent)", preferredStyle: .alert)
                self.present(alertController, animated: true, completion: nil)
                return
            }
            
            // Instantiate and save the document
            let document = Document(fileURL: targetURL)
            document.movieURL = sourceURL
            document.save(to: targetURL, for: .forCreating) { (saveSuccess) in
                guard saveSuccess else {
                    let alertController = UIAlertController(title: "Cannot import video", message: "Document failed to save", preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                    return
                }
                document.close(completionHandler: { (closeSuccess) in
                    guard closeSuccess else {
                        let alertController = UIAlertController(title: "Cannot import video", message: "Document failed post-save", preferredStyle: .alert)
                        self.present(alertController, animated: true, completion: nil)
                        return
                    }
                })
            }
        }
        
        // Present the Document View Controller for the document
        presentDocument(at: targetURL)
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

