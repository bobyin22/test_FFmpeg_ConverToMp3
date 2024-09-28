//
//  ViewController.swift
//  測試0928轉檔
//
//  Created by Bob on 2024/9/28.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import ffmpegkit

class ViewController: UIViewController {

    @IBOutlet weak var clickFileBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemOrange
        clickFileBtn.titleLabel?.textAlignment = .center
    }

    @IBAction func clickBtnShowPickerVC(_ sender: Any) {
        presentDocumentPicker()
    }
    
    private func presentDocumentPicker() {
        // 各種版本iOS音檔影片都可以指定轉成mp3
        if #available(iOS 14.0, *) {
            // UTType這邊需要import UniformTypeIdentifiers 才能使用
            // 使用UTType來指定可以選擇的文件類型
            let types: [UTType] = [UTType.movie, UTType.audio]  // 支援的文件類型：影片和音頻
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            present(documentPicker, animated: true, completion: nil)
        } else {
            // KUTT這邊需要import MobileCoreServices 才能使用
            // 對於舊版本iOS，使用KUTType來指定文件類型
            let documentPicker = UIDocumentPickerViewController(documentTypes: [String(kUTTypeAudio), String(kUTTypeMovie) ],
                                                                in: .import) // 創建文件選擇器
            documentPicker.delegate = self
            present(documentPicker, animated: true, completion: nil)
        }
    }
}

extension ViewController: UIDocumentPickerDelegate {
    // UIDocumentPickerDelegate method
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        clickFileBtn.titleLabel?.text = "轉檔中"
        guard let sourceURL = urls.first else { return } // 獲取選擇的第一個文件URL
        do {
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first! // 獲取文件目錄
            let destinationURL = documentDirectory.appendingPathComponent(sourceURL.lastPathComponent) // 設定目標文件URL
            
            // 如果目標文件已存在，則刪除它
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL) // 刪除已存在的文件
            }
            
            // 移動選擇的文件到目標位置
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL) // 移動文件
            print("File moved to: \(destinationURL.path)") // 打印移動後的文件路徑
            convertToMP3(videoUrl: destinationURL)
        } catch {
            print("Error moving file: \(error)")
        }
    }
    
    ///https://stackoverflow.com/questions/72672889/ffmpeg-for-use-in-ios-application-coded-in-swift ( stakc overflow )
    ///https://github.com/arthenica/ffmpeg-kit/wiki/iOS ( ffmpeg 官網 wiki )
    private func convertToMP3(videoUrl: URL) {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputUrl = documentDirectory.appendingPathComponent("audio.mp3") // 設定輸出文件URL
        
        // 刪除已存在的目標檔案 (沒加第二次選檔案轉檔會失敗)
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            do {
                try FileManager.default.removeItem(at: outputUrl) // 刪除已存在的輸出文件
            } catch {
                print("Error deleting existing output file: \(error)")
            }
        }
        
        //地址
        let ffmpegCommand = "-i '\(videoUrl.path)' '\(outputUrl.path)'" // 指定輸入和輸出文件路徑
        
        //進行轉檔
        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let session = session else {
                print("!! Invalid session")
                return
            }
            guard let returnCode = session.getReturnCode() else {
                print("!! Invalid return code")
                return
            }
            print("印出\(ReturnCode.isSuccess(returnCode))")
            print("FFmpeg process exited with state \(FFmpegKitConfig.sessionState(toString: session.getState()) ?? "Unknown") and rc \(returnCode).\(session.getFailStackTrace() ?? "Unknown")") // 打印FFmpeg進程狀態
            
            //如果成功 ０是成功 1是失敗
            if ReturnCode.isSuccess(returnCode) {
                print("Conversion successful! Return code: \(returnCode)")
                let activityVC = UIActivityViewController(activityItems: [outputUrl], applicationActivities: nil) // 創建分享活動控制器
                DispatchQueue.main.async {
                    self.present(activityVC, animated: true, completion: nil)
                }
            } else {
                print("Conversion failed! Return code: \(returnCode)")
                print("轉檔失敗 傳送取消")
            }
            
        } withLogCallback: { logs in
            guard let logs = logs else { return } // 檢查日誌是否有效
            // CALLED WHEN SESSION PRINTS LOGS
            print("完成\(outputUrl)")
            DispatchQueue.main.async {
                self.clickFileBtn.titleLabel?.text = "點擊按鈕，選擇要轉成MP3的檔案"
            }
            //
        } withStatisticsCallback: { stats in
            guard let stats = stats else { return } // 檢查統計信息是否有效
            // CALLED WHEN SESSION GENERATES STATISTICS
        }
    }
}

