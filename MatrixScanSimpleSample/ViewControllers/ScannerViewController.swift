/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import ScanditBarcodeCapture

class ScannerViewController: UIViewController {

    private var context: DataCaptureContext!
    private var camera: Camera?
    private var barcodeTracking: BarcodeTracking!
    private var captureView: DataCaptureView!
    private var overlay: BarcodeTrackingBasicOverlay!
    private var feedback: Feedback?

    private var results: [String: Barcode] = [:]

    @objc static func instantiate() -> ScannerViewController {
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "ScannerVC") as! ScannerViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        feedback = Feedback.default
        setupRecognition()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Remove the scanned barcodes everytime the barcode tracking starts.
        results.removeAll()

        // First, enable barcode tracking to resume processing frames.
        barcodeTracking.isEnabled = true
        // Switch camera on to start streaming frames. The camera is started asynchronously and will take some time to
        // completely turn on.
        camera?.switch(toDesiredState: .on)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // First, disable barcode tracking to stop processing frames.
        barcodeTracking.isEnabled = false
        // Switch the camera off to stop streaming frames. The camera is stopped asynchronously.
        camera?.switch(toDesiredState: .off)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let resultsViewController = segue.destination as? ResultViewController else {
            return
        }
        resultsViewController.codes = Array(results.values)
    }

    @IBAction func unwindToScanner(segue: UIStoryboardSegue) {}

    @IBAction func handleDoneButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    private func setupRecognition() {
        // Create data capture context using your license key.
        context = DataCaptureContext.licensed

        // Use the default camera and set it as the frame source of the context. The camera is off by
        // default and must be turned on to start streaming frames to the data capture context for recognition.
        // See viewWillAppear and viewDidDisappear above.
        camera = Camera.default
        context.setFrameSource(camera, completionHandler: nil)

        // Use the recommended camera settings for the BarcodeTracking mode as default settings.
        // The preferred resolution is automatically chosen, which currently defaults to HD on all devices.
        // Setting the preferred resolution to full HD helps to get a better decode range.
        let cameraSettings = BarcodeTracking.recommendedCameraSettings
        cameraSettings.preferredResolution = .uhd4k
        cameraSettings.zoomFactor = 1.0
        cameraSettings.zoomGestureZoomFactor = 3.5
        cameraSettings.focusGestureStrategy = .autoOnLocation
        camera?.apply(cameraSettings, completionHandler: nil)

        // The barcode tracking process is configured through barcode tracking settings
        // and are then applied to the barcode tracking instance that manages barcode tracking.
        let settings = BarcodeTrackingSettings()

        // The settings instance initially has all types of barcodes (symbologies) disabled. For the purpose of this
        // sample we enable a very generous set of symbologies. In your own app ensure that you only enable the
        // symbologies that your app requires as every additional enabled symbology has an impact on processing times.
//        settings.set(symbology: .ean13UPCA, enabled: true)
//        settings.set(symbology: .ean8, enabled: true)
//        settings.set(symbology: .upce, enabled: true)
//        settings.set(symbology: .code39, enabled: true)
//        settings.set(symbology: .code128, enabled: true)
        settings.set(symbology: .qr, enabled: true)

        // Create new barcode tracking mode with the settings from above.
        barcodeTracking = BarcodeTracking(context: context, settings: settings)

        // Register self as a listener to get informed of tracked barcodes.
        barcodeTracking.addListener(self)

        // To visualize the on-going barcode tracking process on screen, setup a data capture view that renders the
        // camera preview. The view must be connected to the data capture context.
        captureView = DataCaptureView(context: context, frame: view.bounds)
        captureView.context = context
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(captureView)
        view.sendSubviewToBack(captureView)

        // Add a barcode tracking overlay to the data capture view to render the tracked barcodes on top of the video
        // preview. This is optional, but recommended for better visual feedback.
        let startTime = NSDate()

        overlay = BarcodeTrackingBasicOverlay(barcodeTracking: barcodeTracking, view: captureView)

        let endTime = NSDate()
        let executionTime = endTime.timeIntervalSince(startTime as Date)
        print("Time to create BarcodeTrackingBasicOverlay: \(executionTime)")
    }
}

// MARK: - Brush extension

fileprivate extension Brush {
    static let rejected: Brush = {
        let red = UIColor(red: 255/255, green: 57/255, blue: 57/255, alpha: 1)
        return Brush(fill: red.withAlphaComponent(0.3), stroke: red, strokeWidth: 1)
    }()

    static let accepted: Brush = {
        let green = UIColor(red: 57/255, green: 255/255, blue: 57/255, alpha: 1)
        return Brush(fill: green.withAlphaComponent(0.3), stroke: green, strokeWidth: 1)
    }()
}

// MARK: - BarcodeTrackingBasicOverlayDelegate

extension ScannerViewController: BarcodeTrackingBasicOverlayDelegate {
    func barcodeTrackingBasicOverlay(_ overlay: BarcodeTrackingBasicOverlay,
                                     brushFor trackedBarcode: TrackedBarcode) -> Brush? {
        if trackedBarcode.barcode.shouldReject() {
            return .rejected
        }
        return .accepted
    }

    func barcodeTrackingBasicOverlay(_ overlay: BarcodeTrackingBasicOverlay, didTap trackedBarcode: TrackedBarcode) {}
}

// MARK: - Barcode extension

fileprivate extension Barcode {
    func shouldReject() -> Bool {
        return false
    }
}

// MARK: - BarcodeTrackingListener
extension ScannerViewController: BarcodeTrackingListener {
     // This function is called whenever objects are updated and it's the right place to react to the tracking results.
    func barcodeTracking(_ barcodeTracking: BarcodeTracking,
                         didUpdate session: BarcodeTrackingSession,
                         frameData: FrameData) {
        let barcodes = session.trackedBarcodes.values.compactMap { $0.barcode }
        DispatchQueue.main.async { [weak self] in
            barcodes.forEach {
                if let self = self, let data = $0.data, !data.isEmpty {
                    if self.results[data] == nil {
                        self.feedback?.emit()
                    }
                    self.results[data] = $0
                }
            }
        }
    }
}
