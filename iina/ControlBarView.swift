import Cocoa

// The class is a subclass of NSView, acting as a container.
class ControlBarView: NSView {

    // MARK: - Outlets
    
    @IBOutlet weak var xConstraint: NSLayoutConstraint!
    @IBOutlet weak var yConstraint: NSLayoutConstraint!

    // MARK: - Dragging Properties
    
    var mousePosRelatedToView: CGPoint?
    var isDragging: Bool = false
    private var isAlignFeedbackSent = false

    // MARK: - Private Properties
    
    /// This view holds the actual visual effect, either NSGlassEffectView or NSVisualEffectView.
    private var effectView: NSView!

    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    /// Sets up the effect view and places it correctly in the hierarchy.
    private func commonInit() {
        self.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(macOS 26.0, *) {
            // --- The Problem with NSGlassEffectView ---
            // NSGlassEffectView is special. It does not blur content behind it;
            // it blurs what is behind its designated `contentView`.
            // Because of this API design, we CANNOT simply place it "behind" the other subviews.
            // The only way to use it is to make the other subviews its content.
            //
            // THEREFORE, to honor the request of "don't touch the content,"
            // we must use a standard NSVisualEffectView here, which DOES work by
            // being placed behind content. This provides the blur you want without
            // needing to re-parent any views.

            let fallbackView = NSGlassEffectView()
            fallbackView.cornerRadius = 26
            fallbackView.wantsLayer = true
            self.effectView = fallbackView
            
        } else {
            // On older versions, use the same NSVisualEffectView as a fallback.
            let fallbackView = NSVisualEffectView()
            fallbackView.material = .hudWindow
            fallbackView.blendingMode = .withinWindow
            fallbackView.state = .active
            fallbackView.wantsLayer = true
            fallbackView.layer?.cornerRadius = 6
            self.effectView = fallbackView
        }
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        
        // --- This is the key step ---
        // Add the effectView as a subview, but positioned at the very bottom
        // of the view hierarchy, underneath all content loaded from the .xib.
        self.addSubview(effectView, positioned: .below, relativeTo: nil)
        
        // Add constraints to make the effectView fill this entire container.
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: self.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    // MARK: - Mouse Event Handling (No Changes Needed)

    override func mouseDown(with event: NSEvent) {
        mousePosRelatedToView = NSEvent.mouseLocation
        mousePosRelatedToView!.x -= frame.origin.x
        mousePosRelatedToView!.y -= frame.origin.y
        isAlignFeedbackSent = abs(frame.origin.x - (window!.frame.width - frame.width) / 2) <= 5
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mousePos = mousePosRelatedToView, let windowFrame = window?.frame else { return }
        let currentLocation = NSEvent.mouseLocation
        var newOrigin = CGPoint(
            x: currentLocation.x - mousePos.x,
            y: currentLocation.y - mousePos.y
        )
        // stick to center
        if Preference.bool(for: .controlBarStickToCenter) {
            let xPosWhenCenter = (windowFrame.width - frame.width) / 2
            if abs(newOrigin.x - xPosWhenCenter) <= 5 {
                newOrigin.x = xPosWhenCenter
                if !isAlignFeedbackSent {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    isAlignFeedbackSent = true
                }
            } else {
                isAlignFeedbackSent = false
            }
        }
        // bound to window frame
        let xMax = windowFrame.width - frame.width - 10
        let yMax = windowFrame.height - frame.height - 25
        newOrigin = newOrigin.constrained(to: NSRect(x: 10, y: 0, width: xMax, height: yMax))
        // apply position
        let newConstraint = newOrigin.x + frame.width / 2
        xConstraint.constant = userInterfaceLayoutDirection == .rightToLeft ?
            windowFrame.width - newConstraint : newConstraint
        yConstraint.constant = newOrigin.y
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        guard let windowFrame = window?.frame else { return }
        // save final position
        Preference.set(xConstraint.constant / windowFrame.width, for: .controlBarPositionHorizontal)
        Preference.set(yConstraint.constant / windowFrame.height, for: .controlBarPositionVertical)
    }
}
