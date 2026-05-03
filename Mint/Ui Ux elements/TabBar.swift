import UIKit

enum AppTab: Int {
    case home = 0
    case budget
    case reports
    case goals

    var title: String {
        switch self {
        case .home:    return "Overview"
        case .budget:  return "BUDGET"
        case .reports: return "REPORTS"
        case .goals:   return "GOALS"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "square.grid.2x2"
        case .budget:  return "wallet.bifold"
        case .reports: return "chart.bar"
        case .goals:   return "scope"
        }
    }
}

final class CustomTabBarController: UITabBarController {

    private let barView   = UIView()
    private let stackView = UIStackView()
    private let payButton = UIButton(type: .custom)

    private var tabItems: [TabItemView] = []

    private let barHeight: CGFloat = 80
    private let paySize:   CGFloat = 64
    private let payRise:   CGFloat = 28

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isHidden = true
        setupVCs()
        setupBar()
        setupItems()
        setupPayButton()
        selectedIndex = 0
        updateSelection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutBar()
    }

    private func setupVCs() {
        let sb = UIStoryboard(name: "Main", bundle: nil)

        let home    = sb.instantiateViewController(withIdentifier: "NewHomeViewController")
        let budget  = sb.instantiateViewController(withIdentifier: "BudgetViewController")
        let reports = sb.instantiateViewController(withIdentifier: "ReportsViewController")
        let goals   = sb.instantiateViewController(withIdentifier: "GoalsViewController")

        viewControllers = [
            UINavigationController(rootViewController: home),
            UINavigationController(rootViewController: budget),
            UINavigationController(rootViewController: reports),
            UINavigationController(rootViewController: goals)
        ]
    }

    private func setupBar() {
        barView.backgroundColor    = AppColors.card
        barView.layer.cornerRadius = barHeight / 2
        barView.clipsToBounds      = false
        barView.layer.shadowColor  = UIColor.black.cgColor
        barView.layer.shadowOpacity = 0.10
        barView.layer.shadowOffset  = CGSize(width: 0, height: -2)
        barView.layer.shadowRadius  = 8
        view.addSubview(barView)
    }

    private func setupItems() {
        let home    = TabItemView(tab: .home)
        let budget  = TabItemView(tab: .budget)
        let reports = TabItemView(tab: .reports)
        let goals   = TabItemView(tab: .goals)

        tabItems = [home, budget, reports, goals]

        let spacer = UIView()
        spacer.isUserInteractionEnabled = false

        stackView.axis         = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment    = .fill
        stackView.isUserInteractionEnabled = true

        stackView.addArrangedSubview(home)
        stackView.addArrangedSubview(budget)
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(reports)
        stackView.addArrangedSubview(goals)

        spacer.widthAnchor.constraint(equalTo: home.widthAnchor).isActive = true

        barView.addSubview(stackView)

        for (i, item) in tabItems.enumerated() {
            item.tag = i
            item.isUserInteractionEnabled = true
            item.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(tabTap(_:)))
            )
        }
    }

    private func setupPayButton() {
        payButton.backgroundColor    = AppColors.brand
        payButton.layer.cornerRadius = paySize / 2
        payButton.layer.shadowColor  = AppColors.brand.cgColor
        payButton.layer.shadowOpacity = 0.35
        payButton.layer.shadowOffset  = CGSize(width: 0, height: 4)
        payButton.layer.shadowRadius  = 10

        let img = UIImage(systemName: "plus")?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold))
        payButton.setImage(img, for: .normal)

        view.addSubview(payButton)
        payButton.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
    }

    private func layoutBar() {
        let width = view.bounds.width - 32
        let x: CGFloat = 16
        let y = view.bounds.height - barHeight - 16

        barView.frame   = CGRect(x: x, y: y, width: width, height: barHeight)
        stackView.frame = barView.bounds

        payButton.frame = CGRect(
            x: view.bounds.midX - paySize / 2,
            y: y - payRise,
            width: paySize,
            height: paySize
        )
    }

    @objc private func tabTap(_ g: UITapGestureRecognizer) {
        guard let i = g.view?.tag else { return }
        selectedIndex = i
        updateSelection()
        animateTabItem(at: i)
    }

    @objc private func payTapped() {
        UIView.animate(
            withDuration: 0.12,
            animations: { self.payButton.transform = CGAffineTransform(scaleX: 0.88, y: 0.88) },
            completion: { _ in
                UIView.animate(withDuration: 0.35,
                               delay: 0,
                               usingSpringWithDamping: 0.5,
                               initialSpringVelocity: 8) {
                    self.payButton.transform = .identity
                }
            }
        )
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let payment = sb.instantiateViewController(withIdentifier: "paymentViewController")
        payment.modalPresentationStyle = .pageSheet
        if let sheet = payment.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = false
        }
        present(payment, animated: true)
    }

    private func updateSelection() {
        for (i, item) in tabItems.enumerated() {
            item.setSelected(i == selectedIndex)
        }
    }

    private func animateTabItem(at index: Int) {
        guard index < tabItems.count else { return }
        let item = tabItems[index]
        UIView.animate(
            withDuration: 0.10,
            animations: { item.transform = CGAffineTransform(scaleX: 0.85, y: 0.85) },
            completion: { _ in
                UIView.animate(withDuration: 0.45,
                               delay: 0,
                               usingSpringWithDamping: 0.45,
                               initialSpringVelocity: 10) {
                    item.transform = .identity
                }
            }
        )
    }
}

final class TabItemView: UIView {

    private let icon  = UIImageView()
    private let label = UILabel()
    private let tab:  AppTab

    init(tab: AppTab) {
        self.tab = tab
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        isUserInteractionEnabled = true

        icon.image       = UIImage(systemName: tab.icon)
        icon.tintColor   = AppColors.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        label.text      = tab.title
        label.font      = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = AppColors.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(label)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 3)
        ])
    }

    func setSelected(_ selected: Bool) {
        let color = selected ? AppColors.brand : AppColors.textSecondary
        UIView.animate(withDuration: 0.2) {
            self.icon.tintColor  = color
            self.label.textColor = color
        }
    }
}

final class PlaceholderVC: UIViewController {
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}
