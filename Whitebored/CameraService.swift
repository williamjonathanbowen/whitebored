import AVFoundation
import AppKit

final class CameraService: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photo = AVCapturePhotoOutput()
    private var waiting: CheckedContinuation<Data?, Never>?
    private var started = false

    var isRunning: Bool { session.isRunning }

    func start() async {
        let ok = await AVCaptureDevice.requestAccess(for: .video)
        guard ok else { return }
        if started {
            if !session.isRunning {
                session.startRunning()
            }
            return
        }
        started = true
        session.beginConfiguration()
        session.sessionPreset = .high
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
            ?? AVCaptureDevice.default(for: .video)
        if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photo) {
            session.addOutput(photo)
        }
        if let connection = photo.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
        }
        session.commitConfiguration()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
                cont.resume()
            }
        }
    }

    func jpeg() async -> Data? {
        guard session.isRunning else { return nil }
        return await withCheckedContinuation { cont in
            if waiting != nil {
                cont.resume(returning: nil)
                return
            }
            waiting = cont
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            photo.capturePhoto(with: settings, delegate: self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.finish(nil)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        DispatchQueue.main.async {
            self.finish(data)
        }
    }

    private func finish(_ data: Data?) {
        guard let waiting else { return }
        self.waiting = nil
        waiting.resume(returning: data)
    }
}

final class CameraPreviewView: NSView {
    let preview = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        preview.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer {
        preview
    }

    override func layout() {
        super.layout()
        preview.frame = bounds
    }
}
