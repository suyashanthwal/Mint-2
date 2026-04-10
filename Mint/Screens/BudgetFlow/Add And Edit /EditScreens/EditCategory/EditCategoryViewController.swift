//
//  EditCategoryViewController.swift
//  EditPages
//
//  Created by Anushk Barmola on 07/02/26.
//

import UIKit

class EditCategoryViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var limitTextField: UITextField!
    @IBOutlet weak var iconPickerStackView: UIStackView!
    @IBOutlet weak var iconPickerImageView: UIImageView!
    @IBOutlet weak var iconPickerLabel: UILabel!
    @IBOutlet weak var iconCollectionView: UICollectionView!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var iconCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var IconColorWheelSelector: UIColorWell!
    @IBOutlet var AllView: [UIView]!
    @IBOutlet var InsideViews: [UIView]!
  //  @IBOutlet var InsideStackView: [UIStackView]!

    // Edit-only outlet — shows the calculated remaining amount (read-only)
    @IBOutlet weak var remainingAmountTextField: UITextField!

    // MARK: - Edit-only Properties

    var category: Category?
    var onCategoryUpdated: (() -> Void)?

    // MARK: - Shared Private Properties

    private var isIconPickerExpanded = false
    private let collapsedHeight: CGFloat = 0
    private let expandedHeight: CGFloat = 400

    private var selectedIconName: String?
    private var selectedIconColor: UIColor = AppColors.brand

    private let iconCategories: [String: [String]] = CategoryData.iconCategories

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        view.backgroundColor = AppColors.background
        setupUI()
        setupColorWell()
        setupIconCollectionView()
        loadCategory()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColors.background
        for v in AllView {
            v.backgroundColor = AppColors.background
        }

        for v in InsideViews {
            v.backgroundColor = AppColors.card
            v.applyShadow()
        }

//        for eachStack in InsideStackView {
//            eachStack.backgroundColor = AppColors.card
//        }

        // ── Text Fields ───────────────────────────────────────
        nameTextField.backgroundColor = AppColors.card
        nameTextField.textColor       = AppColors.textPrimary

        limitTextField.backgroundColor = AppColors.card
        limitTextField.textColor       = AppColors.textPrimary
        limitTextField.keyboardType    = .numberPad

        // ── Remaining Amount (read-only display) ──────────────
        remainingAmountTextField.backgroundColor          = AppColors.card
        remainingAmountTextField.textColor                = AppColors.textPrimary
        remainingAmountTextField.isUserInteractionEnabled = false

        // ── Icon Picker row ───────────────────────────────────
        iconPickerImageView.backgroundColor = .clear
        iconPickerImageView.tintColor       = selectedIconColor
        iconPickerLabel.backgroundColor     = .clear

        // ── Icon Collection View ──────────────────────────────
        iconCollectionView.backgroundColor = AppColors.card
        iconCollectionView.clipsToBounds   = true

        // ── Notes Text View ───────────────────────────────────
        notesTextView.backgroundColor    = AppColors.card
        notesTextView.layer.borderColor  = UIColor.systemGray5.cgColor
        notesTextView.layer.borderWidth  = 1
        notesTextView.layer.cornerRadius = 8

        // ── Icon Picker Collapse State ────────────────────────
        iconCollectionViewHeightConstraint.constant = collapsedHeight
        iconCollectionView.isHidden = true

        // ── Icon Picker tap gesture ───────────────────────────
        let tap = UITapGestureRecognizer(target: self, action: #selector(iconPickerTapped))
        iconPickerStackView.addGestureRecognizer(tap)
        iconPickerStackView.isUserInteractionEnabled = true
    }

    private func setupColorWell() {
        IconColorWheelSelector.selectedColor = selectedIconColor
        IconColorWheelSelector.supportsAlpha = false
        IconColorWheelSelector.addTarget(self, action: #selector(colorWellChanged(_:)), for: .valueChanged)
    }

    private func setupIconCollectionView() {
        iconCollectionView.delegate   = self
        iconCollectionView.dataSource = self

        iconCollectionView.register(
            UINib(nibName: "IconCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "IconCell"
        )
        iconCollectionView.register(
            UINib(nibName: "IconHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "IconHeaderView"
        )

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection         = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing      = 10
        layout.headerReferenceSize     = CGSize(width: iconCollectionView.frame.width, height: 40)
        iconCollectionView.collectionViewLayout = layout
    }

    // MARK: - Load Existing Category (Edit-only)

    private func loadCategory() {
        guard let category = category else { return }

        title = category.name

        nameTextField.text            = category.name
        limitTextField.text           = String(Int(category.budget))
        remainingAmountTextField.text = String(Int(category.remaining))

        selectedIconName          = category.icon
        iconPickerImageView.image = UIImage(systemName: category.icon)
        iconPickerLabel.text      = formatIconName(category.icon)

        // Restore the saved icon color, falling back to brand
        let savedColor = UIColor(hex: category.color)
        selectedIconColor                    = savedColor
        iconPickerImageView.tintColor        = savedColor
        IconColorWheelSelector.selectedColor = savedColor
    }

    // MARK: - Color Well Action

    @objc private func colorWellChanged(_ sender: UIColorWell) {
        guard let color = sender.selectedColor else { return }
        selectedIconColor             = color
        iconPickerImageView.tintColor = color
    }

    // MARK: - IBActions

    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func saveButtonTapped(_ sender: Any) {
        guard
            let category = category,
            let name     = nameTextField.text,
            !name.trimmingCharacters(in: .whitespaces).isEmpty,
            let iconName = selectedIconName
        else {
            showValidationError()
            return
        }

        let limitText = limitTextField.text ?? ""
        let budget    = Double(limitText.filter { $0.isNumber || $0 == "." }) ?? 0
        let colorHex  = selectedIconColor.toHex() ?? "#CCCCCC"

        DatabaseManager.shared.updateCategory(
            id:     category.id,
            name:   name.trimmingCharacters(in: .whitespaces),
            color:  colorHex,
            icon:   iconName,
            budget: budget
        )

        dismiss(animated: true) {
            self.onCategoryUpdated?()
            NotificationCenter.default.post(name: .categoryDataDidChange, object: nil)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        }
    }

    private func showValidationError() {
        let message = selectedIconName == nil
            ? "Please select an icon for the category."
            : "Please enter a category name."
        let alert = UIAlertController(
            title: "Missing Information",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Icon Picker Expand / Collapse

    @objc private func iconPickerTapped() {
        isIconPickerExpanded.toggle()
        UIView.animate(withDuration: 0.3) {
            if self.isIconPickerExpanded {
                self.iconCollectionViewHeightConstraint.constant = self.expandedHeight
                self.iconCollectionView.isHidden = false
            } else {
                self.iconCollectionViewHeightConstraint.constant = self.collapsedHeight
                self.iconCollectionView.isHidden = true
            }
            self.view.layoutIfNeeded()
        }
    }

    private func formatIconName(_ systemName: String) -> String {
        let words = systemName.split(separator: ".")
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

// MARK: - UICollectionViewDataSource

extension EditCategoryViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        iconCategories.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Array(iconCategories.values)[section].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "IconCell", for: indexPath
        ) as! IconCollectionViewCell
        let iconName = Array(iconCategories.values)[indexPath.section][indexPath.item]
        cell.configure(with: iconName)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "IconHeaderView",
            for: indexPath
        ) as! IconHeaderCollectionReusableView
        header.configure(with: Array(iconCategories.keys)[indexPath.section])
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension EditCategoryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let iconName     = Array(iconCategories.values)[indexPath.section][indexPath.item]
        selectedIconName = iconName

        iconPickerImageView.image     = UIImage(systemName: iconName)
        iconPickerImageView.tintColor = selectedIconColor
        iconPickerLabel.text          = formatIconName(iconName)
        iconPickerTapped() // collapse the picker
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EditCategoryViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: 50, height: 50)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    }
}

// MARK: - UIColor toHex

private extension UIColor {
    func toHex() -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
