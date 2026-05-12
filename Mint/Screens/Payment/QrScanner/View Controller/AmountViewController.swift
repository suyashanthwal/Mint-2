
import UIKit

class AmountViewController: UIViewController, UITextFieldDelegate {
    
    

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var badgeImageView: UIImageView!
    
    
    @IBOutlet weak var payeeNameLabel: UILabel!
    @IBOutlet weak var upiIDLabel: UILabel!
    @IBOutlet weak var amountLabel: UITextField!
    @IBOutlet weak var categoryContainerView: UIView!
    @IBOutlet weak var sendButton: UIButton!
    
    @IBOutlet weak var categoryCollectionView: UICollectionView!
    
    @IBOutlet var note: UITextField!
    var upiData: UPIQRCodeData?
    private var amount: Double = 0
    private var selectedCategoryIndex: Int = 0
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let db = DatabaseManager.shared
    
    private var categories: [Category] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadCategoriesFromDatabase()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        setupCategoryCollectionView()
        configureWithData()
        feedbackGenerator.prepare()
    }
    
    private func showUPIAppPicker() {
        guard let data = upiData else { return }
        
        
        
        
        let upiAppSchemes = ["tez://upi/pay", "paytm://", "bhim://", "phonepe://", "amazonpay://"]
        
        let hasAnyUPIApp = upiAppSchemes.contains {
            guard let url = URL(string: $0) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
        
        guard hasAnyUPIApp else {
            showNoUPIAppAlert()
            return
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let picker = storyboard.instantiateViewController(
            withIdentifier: "UPIAppPickerViewController"
        ) as? UPIAppPickerViewController else {
            assertionFailure("UPIAppPickerViewController not found")
            return
        }

        let selectedCategory = selectedCategoryForSelection()
        let selectedCategoryName = selectedCategory?.name ?? "Others"
        let transactionNote = note.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let paymentNote = (transactionNote?.isEmpty == false)
            ? transactionNote
            : nil

        picker.upiData = data
        picker.amount = amount
        picker.categoryName = paymentNote ?? selectedCategoryName
        picker.categoryId = selectedCategory.flatMap { db.fetchCategory(named: $0.name)?.id }
        picker.transactionName = data.payeeName ?? extractNameFromUPI(data.payeeID)
        picker.transactionNote = paymentNote
        picker.modalPresentationStyle = .pageSheet

        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }

        present(picker, animated: true)
    }
    private func showNoUPIAppAlert() {
        let alert = UIAlertController(
            title: "No UPI App Found",
            message: "Please install a UPI payment app like GPay, PhonePe, or Paytm to proceed.",
            preferredStyle: .alert
        )
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func setupCategoryCollectionView() {
        categoryCollectionView.register(
            UINib(nibName: "CategoryCell", bundle: nil),
            forCellWithReuseIdentifier: CategoryCell.reuseID
        )
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.showsHorizontalScrollIndicator = false
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 80, height: 90)
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        categoryCollectionView.collectionViewLayout = layout
    }

    private func loadCategoriesFromDatabase() {
        categories = db.fetchCategories().filter { $0.type == .expense }

        if categories.isEmpty {
            _ = db.ensureCategory(
                name: "Others",
                color: "#7D8597",
                icon: "cube.box.fill",
                budget: 0,
                type: .expense
            )
            categories = db.fetchCategories().filter { $0.type == .expense }
        }

        if categories.isEmpty {
            categories = [
                Category(
                    name: "Others",
                    color: "#7D8597",
                    icon: "cube.box.fill",
                    budget: 0,
                    type: .expense
                )
            ]
        }

        if selectedCategoryIndex >= categories.count {
            selectedCategoryIndex = 0
        }
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.background
        view.overrideUserInterfaceStyle = .dark
        navigationController?.navigationBar.tintColor = AppColors.brand
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 17, weight: .semibold)
        ]

        payeeNameLabel.textColor = AppColors.textPrimary
        upiIDLabel.textColor = AppColors.textSecondary
        note.textColor = AppColors.textPrimary
        note.tintColor = AppColors.brand
        note.backgroundColor = AppColors.inputBackground
        note.layer.cornerRadius = 12
        note.layer.borderWidth = 1
        note.layer.borderColor = AppColors.cardBorder.cgColor
        note.applyMintPlaceholderFont()

        badgeImageView.tintColor = AppColors.success
        
        profileImageView?.layer.cornerRadius = 50
        profileImageView?.clipsToBounds = true
        profileImageView?.backgroundColor = AppColors.brand
        
        sendButton?.layer.cornerRadius = 25
        sendButton?.clipsToBounds = true
        sendButton?.backgroundColor = AppColors.brand
        sendButton?.tintColor = AppColors.brandText
        sendButton?.setTitleColor(AppColors.brandText, for: .normal)

        categoryContainerView?.backgroundColor = AppColors.card
        categoryContainerView?.layer.cornerRadius = 18
        categoryContainerView?.layer.borderWidth = 1
        categoryContainerView?.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.7).cgColor

        amountLabel.delegate = self
        amountLabel.keyboardType = .decimalPad
        amountLabel.textColor = AppColors.textPrimary
        amountLabel.tintColor = AppColors.brand
        amountLabel.backgroundColor = .clear
        amountLabel.applyMintPlaceholderFont()
        amountLabel.addTarget(self, action: #selector(amountFieldChanged(_:)), for: .editingChanged)
        view.applyMintTypography()
    }
    

    
    private func configureWithData() {
        guard let data = upiData else { return }
        
        let name = data.payeeName ?? extractNameFromUPI(data.payeeID)
        payeeNameLabel?.text = "Paying \(name.uppercased())"
        upiIDLabel?.text = data.payeeID
        
        setProfileInitial(name)
        
        if data.amount > 0 {
            amount = data.amount
        }
        updateAmountDisplay()
    }
    
    private func setProfileInitial(_ name: String) {
        let initial = String(name.prefix(1)).uppercased()
        profileImageView?.backgroundColor = AppColors.brand
        
        let label = UILabel()
        label.text = initial
        label.font = MintFont.space(size: 40, weight: .semibold)
        label.textColor = AppColors.brandText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        profileImageView?.subviews.forEach { $0.removeFromSuperview() }
        profileImageView?.addSubview(label)
        
        if let imageView = profileImageView {
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])
        }
    }
    
    private func updateAmountDisplay() {
        if amount == 0 {
            amountLabel?.text = ""
        } else {
            amountLabel?.text = formattedAmountText(amount)
        }
    }
    
    private func extractNameFromUPI(_ upiID: String) -> String {
        if let atIndex = upiID.firstIndex(of: "@") {
            return String(upiID[..<atIndex]).capitalized
        }
        return upiID
    }

    private func selectedCategoryForSelection() -> Category? {
        guard categories.indices.contains(selectedCategoryIndex) else { return nil }
        return categories[selectedCategoryIndex]
    }
    
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @IBAction func helpTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(
            title: "Help",
            message: "This screen lets you choose a category and send the payment.",
            preferredStyle: .alert
        )
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func sendTapped(_ sender: UIButton) {
        amount = parsedAmount(from: amountLabel.text)
        guard amount > 0 else {
            amountLabel.becomeFirstResponder()
            return
        }
        feedbackGenerator.impactOccurred()
        showUPIAppPicker()
    }

    @objc private func amountFieldChanged(_ textField: UITextField) {
        amount = parsedAmount(from: textField.text)
    }

    private func formattedAmountText(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }

    private func parsedAmount(from text: String?) -> Double {
        let sanitized = (text ?? "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(sanitized) ?? 0
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === amountLabel && amount == 0 {
            textField.text = nil
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === amountLabel {
            amount = parsedAmount(from: textField.text)
            updateAmountDisplay()
        }
    }
}
    extension AmountViewController: UICollectionViewDataSource,
                                    UICollectionViewDelegate {
        
        func collectionView(_ collectionView: UICollectionView,
                            numberOfItemsInSection section: Int) -> Int {
            categories.count
        }
        
        func collectionView(_ collectionView: UICollectionView,
                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CategoryCell.reuseID,
                for: indexPath
            ) as! CategoryCell
            
            cell.configure(with: categories[indexPath.item],
                           isSelected: indexPath.item == selectedCategoryIndex)
            return cell
        }
        
        func collectionView(_ collectionView:              UICollectionView,didSelectItemAt indexPath: IndexPath) {
            feedbackGenerator.impactOccurred()
            let previousIndex = selectedCategoryIndex
            selectedCategoryIndex = indexPath.item
            var indexPathsToReload = [indexPath]
            if categories.indices.contains(previousIndex) {
                indexPathsToReload.append(IndexPath(item: previousIndex, section: 0))
            }
            categoryCollectionView.reloadItems(at: Array(Set(indexPathsToReload)))
        }
    }
