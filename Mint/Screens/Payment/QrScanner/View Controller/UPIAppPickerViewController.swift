
import UIKit

class UPIAppPickerViewController: UIViewController {

        var upiData: UPIQRCodeData?
        var amount: Double = 0
        var categoryName: String = ""
        var categoryId: UUID?
        var transactionName: String?
        var transactionNote: String?

        private let allUPIApps: [(name: String, scheme: String)] = [
            ("Google Pay",  "tez://upi/pay"),
            ("Paytm",       "paytm://"),
            ("Bhim UPI",    "bhim://"),
            ("PhonePe",     "phonepe://"),
            ("Amazon Pay",  "amazonpay://")
        ]

        private var installedUPIApps: [(name: String, scheme: String)] = []
        private var hasBufferedHandoff = false

        @IBOutlet weak var collectionView: UICollectionView!
    
        @IBOutlet weak var collectionViewHeight: NSLayoutConstraint!

        override func viewDidLoad() {
            super.viewDidLoad()
            setupUI()
            setupCollectionView()
        }

        private func setupUI() {
            view.backgroundColor = AppColors.background
            view.overrideUserInterfaceStyle = .dark
            view.applyMintTypography()
        }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        detectInstalledApps()
        collectionView.reloadData()
    }

        private func detectInstalledApps() {
            installedUPIApps = allUPIApps.filter { app in
                guard let url = URL(string: app.scheme) else { return false }
                return UIApplication.shared.canOpenURL(url)
            }

            if installedUPIApps.isEmpty {
                   dismiss(animated: true) {
                   }
                   return
               }

            collectionViewHeight.constant = CGFloat(installedUPIApps.count) * 60
        }

        private func showNoAppsWarning() {
            let alert = UIAlertController(
                title: "No UPI App Found",
                message: "No UPI payment app was detected. Please install Google Pay, PhonePe, or Paytm.",
                preferredStyle: .alert
            )
            alert.overrideUserInterfaceStyle = .dark
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }

        private func setupCollectionView() {
            collectionView.register(
                UINib(nibName: "UPIAppCell", bundle: nil),
                forCellWithReuseIdentifier: UPIAppCell.reuseID
            )
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.backgroundColor = .clear

            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            collectionView.collectionViewLayout = layout
        }

        private func openUPIApp(scheme: String) {
            guard let data = upiData else { return }

            let queryItems = [
                URLQueryItem(name: "pa", value: data.payeeID),
                URLQueryItem(name: "pn", value: data.payeeName ?? ""),
                URLQueryItem(name: "am", value: String(format: "%.2f", amount)),
                URLQueryItem(name: "cu", value: "INR"),
                URLQueryItem(name: "tn", value: categoryName)
            ]

            let appSpecificURL = buildUPIURL(
                scheme: scheme,
                queryItems: queryItems
            )
            let fallbackURL = buildUPIURL(
                scheme: "upi://pay",
                queryItems: queryItems
            )

            guard let upiURL = appSpecificURL ?? fallbackURL else { return }

            bufferPendingTransactionIfNeeded()

            dismiss(animated: true) {
                UIApplication.shared.open(upiURL)
            }
        }

        private func bufferPendingTransactionIfNeeded() {
            guard !hasBufferedHandoff, amount > 0 else { return }

            let trimmedTransactionName = transactionName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPayeeName = upiData?.payeeName?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let merchantName: String?
            if let trimmedTransactionName, !trimmedTransactionName.isEmpty {
                merchantName = trimmedTransactionName
            } else if let trimmedPayeeName, !trimmedPayeeName.isEmpty {
                merchantName = trimmedPayeeName
            } else {
                merchantName = upiData?.payeeID
            }

            guard let name = merchantName, !name.isEmpty else { return }

            let insertedId = DatabaseManager.shared.insertBufferedExpenseTransaction(
                name: name,
                amount: amount,
                timestamp: Date(),
                categoryId: categoryId,
                status: true,
                expenseType: "UPI",
                source: .upi,
                note: transactionNote
            )

            guard insertedId != nil else { return }

            hasBufferedHandoff = true
            NotificationCenter.default.post(name: .bufferTransactionDataDidChange, object: nil)
        }

        private func buildUPIURL(scheme: String, queryItems: [URLQueryItem]) -> URL? {
            guard let baseURL = URL(string: scheme),
                  let schemeName = baseURL.scheme else {
                return nil
            }

            var components = URLComponents()
            components.scheme = schemeName
            components.host = baseURL.host ?? "pay"
            components.path = baseURL.path
            components.queryItems = queryItems
            return components.url
        }

        @IBAction func cancelTapped(_ sender: UIButton) {
            dismiss(animated: true)
        }
    }

    extension UPIAppPickerViewController: UICollectionViewDataSource,
                                           UICollectionViewDelegateFlowLayout {

        func collectionView(_ collectionView: UICollectionView,
                            numberOfItemsInSection section: Int) -> Int {
            return installedUPIApps.count
        }

        func collectionView(_ collectionView: UICollectionView,
                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: UPIAppCell.reuseID,
                for: indexPath
            ) as! UPIAppCell

            let app = installedUPIApps[indexPath.item]
            cell.configure(name: app.name, isFirst: indexPath.item == 0)
            return cell
        }

        func collectionView(_ collectionView: UICollectionView,
                            layout collectionViewLayout: UICollectionViewLayout,
                            sizeForItemAt indexPath: IndexPath) -> CGSize {
            return CGSize(width: collectionView.bounds.width, height: 60)
        }

        func collectionView(_ collectionView: UICollectionView,
                            didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: true)
            let app = installedUPIApps[indexPath.item]
            openUPIApp(scheme: app.scheme)
        }
    }
