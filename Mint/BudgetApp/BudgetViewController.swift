import UIKit

final class BudgetViewController: UIViewController {

    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var profileButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStackView: UIStackView!

    @IBOutlet private weak var totalSpendingCardView: UIView!
    @IBOutlet private weak var totalBudgetTitleLabel: UILabel!
    @IBOutlet private weak var totalBudgetAmountLabel: UILabel!
    @IBOutlet private weak var daysLeftLabel: UILabel!
    @IBOutlet private weak var spentLabel: UILabel!
    @IBOutlet private weak var editButton: UIButton!

    @IBOutlet private var metricCardViews: [UIView]!
    @IBOutlet private var metricTitleLabels: [UILabel]!
    @IBOutlet private var metricAmountLabels: [UILabel]!

    @IBOutlet private weak var categoriesTitleLabel: UILabel!
    @IBOutlet private weak var categoriesCollectionView: UICollectionView!
    @IBOutlet private weak var subsAndBillsTitleLabel: UILabel!
    @IBOutlet private weak var subsAndBillsCollectionView: UICollectionView!
    @IBOutlet private weak var savingGoalsTitleLabel: UILabel!
    @IBOutlet private weak var goalsCollectionView: UICollectionView!

    private let categoryItems: [BudgetCategoryItem] = [
        .init(title: "Food", amount: "₹1,400 / ₹3,000", symbolName: "fork.knife", progress: 0.46, accentColor: UIColor(hex: "#B7152D"), backgroundColor: UIColor(hex: "#330619"), iconColor: UIColor(hex: "#6F0F1A")),
        .init(title: "Travel", amount: "₹1,400 / ₹3,000", symbolName: "car.fill", progress: 0.46, accentColor: UIColor(hex: "#41D441"), backgroundColor: UIColor(hex: "#092813"), iconColor: UIColor(hex: "#1C6B29")),
        .init(title: "Physical", amount: "₹1,400 / ₹3,000", symbolName: "figure.run", progress: 0.46, accentColor: UIColor(hex: "#7147D8"), backgroundColor: UIColor(hex: "#1C143F"), iconColor: UIColor(hex: "#4A3497")),
        .init(title: "Entertainment", amount: "₹1,400 / ₹3,000", symbolName: "movieclapper.fill", progress: 0.46, accentColor: UIColor(hex: "#0F7FB8"), backgroundColor: UIColor(hex: "#061D39"), iconColor: UIColor(hex: "#14699B"))
    ]

    private let billItems: [BudgetBillItem] = [
        .init(title: "Gym", amount: "₹1099", date: "29 April", symbolName: "duffle.bag.fill", dotColor: UIColor(hex: "#7048FF")),
        .init(title: "Netflix", amount: "₹699", date: "29 April", symbolName: "n.circle", dotColor: UIColor(hex: "#0E85DD")),
        .init(title: "Zomato", amount: "₹99", date: "29 April", symbolName: "z.circle", dotColor: UIColor(hex: "#EA1117"))
    ]

    private let goalItems: [BudgetGoalItem] = [
        .init(title: "Headphones", amount: "₹700/month", symbolName: "headphones"),
        .init(title: "Sneakers", amount: "₹300/month", symbolName: "shoeprints.fill")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollections()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyTotalBudgetGradient()
    }

    private func setupCollections() {
        categoriesCollectionView.register(UINib(nibName: CategoryCollectionViewCell.reuseIdentifier, bundle: nil), forCellWithReuseIdentifier: CategoryCollectionViewCell.reuseIdentifier)
        subsAndBillsCollectionView.register(UINib(nibName: BillCollectionViewCell.reuseIdentifier, bundle: nil), forCellWithReuseIdentifier: BillCollectionViewCell.reuseIdentifier)
        goalsCollectionView.register(UINib(nibName: GoalCollectionViewCell.reuseIdentifier, bundle: nil), forCellWithReuseIdentifier: GoalCollectionViewCell.reuseIdentifier)

        [categoriesCollectionView, subsAndBillsCollectionView, goalsCollectionView].forEach {
            $0?.dataSource = self
            $0?.delegate = self
            $0?.backgroundColor = .clear
            $0?.showsHorizontalScrollIndicator = false
        }
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background
        headerView.backgroundColor = AppColors.background
        scrollView.backgroundColor = AppColors.background
        contentStackView.backgroundColor = AppColors.background

        titleLabel.textColor = AppColors.textPrimary
        titleLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        profileButton.tintColor = AppColors.background
        profileButton.backgroundColor = AppColors.textPrimary
        profileButton.layer.cornerRadius = 25

        totalSpendingCardView.layer.cornerRadius = 18
        totalSpendingCardView.clipsToBounds = true
        totalBudgetTitleLabel.textColor = AppColors.brandText
        totalBudgetAmountLabel.textColor = AppColors.brandText
        daysLeftLabel.textColor = AppColors.brandLightText
        spentLabel.textColor = AppColors.brandLightText

        var config = UIButton.Configuration.plain()
        config.title = "Edit"
        config.baseForegroundColor = AppColors.brandText
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        editButton.configuration = config
        editButton.layer.borderColor = AppColors.brandLightText.withAlphaComponent(0.55).cgColor
        editButton.layer.borderWidth = 1
        editButton.layer.cornerRadius = 15

        metricCardViews.forEach {
            $0.backgroundColor = AppColors.card
            $0.layer.cornerRadius = 18
            $0.layer.borderColor = AppColors.cardBorder.cgColor
            $0.layer.borderWidth = 1
        }
        metricTitleLabels.forEach { $0.textColor = AppColors.textPrimary }
        metricAmountLabels.forEach { $0.textColor = AppColors.textPrimary }

        [categoriesTitleLabel, subsAndBillsTitleLabel, savingGoalsTitleLabel].forEach {
            $0?.textColor = AppColors.textPrimary
            $0?.font = .systemFont(ofSize: 18, weight: .bold)
        }
    }

    private func applyTotalBudgetGradient() {
        totalSpendingCardView.layer.sublayers?
            .filter { $0.name == "totalBudgetGradient" }
            .forEach { $0.removeFromSuperlayer() }

        let gradientLayer = CAGradientLayer()
        gradientLayer.name = "totalBudgetGradient"
        gradientLayer.colors = AppColors.brandGradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.15)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.85)
        gradientLayer.frame = totalSpendingCardView.bounds
        totalSpendingCardView.layer.insertSublayer(gradientLayer, at: 0)
    }
}

extension BudgetViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoriesCollectionView { return categoryItems.count }
        if collectionView == subsAndBillsCollectionView { return billItems.count }
        return goalItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoryCollectionViewCell.reuseIdentifier, for: indexPath) as! CategoryCollectionViewCell
            cell.configure(with: categoryItems[indexPath.item])
            return cell
        }

        if collectionView == subsAndBillsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BillCollectionViewCell.reuseIdentifier, for: indexPath) as! BillCollectionViewCell
            cell.configure(with: billItems[indexPath.item])
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GoalCollectionViewCell.reuseIdentifier, for: indexPath) as! GoalCollectionViewCell
        cell.configure(with: goalItems[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == categoriesCollectionView {
            let width = (collectionView.bounds.width - 18) / 2
            return CGSize(width: width, height: 132)
        }

        if collectionView == subsAndBillsCollectionView {
            return CGSize(width: 128, height: 180)
        }

        return CGSize(width: collectionView.bounds.width, height: 86)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == goalsCollectionView ? 14 : 18
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        18
    }
}
