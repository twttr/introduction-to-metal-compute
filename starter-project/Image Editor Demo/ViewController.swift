import UIKit
import Alloy
import SnapKit
import TextureView
import SettingsViewController

class ViewController: UIViewController {

    // MARK: - Properties
    
    private let picker = UIImagePickerController()
    private let settings = SettingsTableViewController()
    private let textureView: TextureView
    
    private let context: MTLContext
    private let adjustments: Adjustments
    private var temperature: Float = .zero
    private var tint: Float = .zero
    private var texturePair: (source: MTLTexture, destination: MTLTexture)?
    
    enum Error: Swift.Error {
        case commandQueueCreationFailed
    }

    // MARK: - Init
    
    init(context: MTLContext) throws {
        self.context = context
        self.adjustments = try .init(library: context.library(for: .main))
        self.textureView = try .init(device: context.device)
        super.init(nibName: nil, bundle: nil)
        
        self.commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        self.picker.delegate = self
        self.view.backgroundColor = .systemBackground
        
        self.title = "image editor demo"
        self.navigationItem.leftBarButtonItem = .init(barButtonSystemItem: .camera,
                                                      target: self,
                                                      action: #selector(self.pickImage))
        self.navigationItem.rightBarButtonItems = [
            .init(barButtonSystemItem: .action,
                  target: self,
                  action: #selector(self.share))
        ]

        // settings

        self.settings.settings = [
            FloatSetting(name: "Temperature",
                         defaultValue: .zero,
                         min: -1,
                         max: 1) {
                self.temperature = $0
                self.redraw()
            },
            FloatSetting(name: "Tint",
                         defaultValue: .zero,
                         min: -1,
                         max: 1) {
                self.tint = $0
                self.redraw()
            },
        ]
        
        guard let settingsView = self.settings.view
        else { return }
        self.settings.tableView.isScrollEnabled = false
        self.addChild(self.settings)
        self.view.addSubview(settingsView)
        settingsView.snp.makeConstraints {
            $0.left.right.equalToSuperview()
            $0.bottom.equalTo(self.view.safeAreaLayoutGuide).inset(20)
            $0.height.equalTo(self.settings.contentHeight)
        }
        
        // image view

        // texture view
        self.textureView.textureContentMode = .aspectFit
        self.textureView.layer.cornerRadius = 10
        self.textureView.layer.masksToBounds = true
        self.view.addSubview(self.textureView)
        self.textureView.backgroundColor = .tertiarySystemFill
        self.textureView.snp.makeConstraints {
            $0.left.right.equalToSuperview().inset(20)
            $0.top.equalTo(self.view.safeAreaLayoutGuide).inset(20)
            $0.bottom.equalTo(settingsView.snp.top).inset(-20)
        }
    }

    // MARK: - Life Cycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    // MARK: - Actions
    
    private func redraw() {
        guard let source = self.texturePair?.source else { return }
        guard let destination = self.texturePair?.destination else { return }
        
        DispatchQueue.main.async {
            try? self.context.schedule { commandBuffer in
                self.adjustments.encode(
                    source: source, 
                    destination: destination,
                    temperature: self.temperature,
                    tint: self.tint,
                    in: commandBuffer
                )
                self.textureView.draw(in: commandBuffer)
            }
        }
    }

    @objc
    private func share() {
        guard let destination = texturePair?.destination else { return }
        guard let image = try? destination.image() else { return }

        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        self.present(vc, animated: true)
    }

    @objc
    private func pickImage() {
        let alert = UIAlertController(title: "Select source",
                                      message: nil,
                                      preferredStyle: .actionSheet)
        alert.addAction(.init(title: "Camera", style: .default) { _ in
            self.picker.sourceType = .camera
            self.present(self.picker, animated: true)
        })
        alert.addAction(.init(title: "Library", style: .default) { _ in
            self.picker.sourceType = .photoLibrary
            self.present(self.picker, animated: true)
        })
        alert.addAction(.init(title: "Cancel",
                              style: .destructive) { _ in })
        self.present(alert, animated: true)
    }

    func handlePickedImage(image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        guard let source = try? self.context.texture(from: cgImage, srgb: false, usage: .shaderRead) else { return }
        guard let destination = try? source.matchingTexture(usage: [.shaderRead, .shaderWrite]) else { return }
        
        self.texturePair = (source, destination)
        self.textureView.texture = destination
        self.redraw()
    }
}
