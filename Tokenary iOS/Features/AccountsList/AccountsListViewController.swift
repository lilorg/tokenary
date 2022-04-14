// Copyright © 2022 Tokenary. All rights reserved.

import Foundation

import UIKit
import SwiftUI
import WalletCore

class AccountsListViewController: LifecycleObservableViewController, DataStateContainer, ActivityIndicatorDisplayable {
    
    // MARK: - Subview Properties
    
    private lazy var addAccountBarItemButton = UIBarButtonItem(
        systemItem: .add, primaryAction: nil, menu: nil
    ).then {
        let createNewAction = UIAction(title: Strings.createNew) { _ in
            self.didTapCreateNewMnemonicWallet()
        }
        let importExistingAction = UIAction(title: Strings.importExisting) { _ in
            self.didTapImportExistingAccount()
        }
        let menu = UIMenu(
            title: Strings.addAccount,
            children: [createNewAction, importExistingAction]
        )
        $0.menu = menu
        if UIDevice.isPad {
            self.updateDataState(menu: menu)
        } else {
            let actionHandler: UIActionHandler = { [weak self] _ in
                let createNewAction = UIAlertAction(title: Strings.createNew, style: .default) { _ in
                    self?.didTapCreateNewMnemonicWallet()
                }
                let importExistingAction = UIAlertAction(title: Strings.importExisting, style: .default) { _ in
                    self?.didTapImportExistingAccount()
                }
                let cancelAction = UIAlertAction(title: Strings.cancel, style: .cancel)
                let alertVC = UIAlertController(
                    title: Strings.addAccount, message: nil, preferredStyle: .actionSheet
                ).then {
                    $0.addAction(createNewAction)
                    $0.addAction(importExistingAction)
                    $0.addAction(cancelAction)
                }
                self?.present(alertVC, animated: true, completion: nil)
            }
            self.updateDataState(actionHandler: actionHandler)
        }
        $0.accessibilityIdentifier = "AddAccountBarItemButton"
        $0.accessibilityLabel = "AddAccountBarItemButton"
        $0.isAccessibilityElement = true
    }

    private lazy var preferencesBarButtonItem = UIBarButtonItem().then {
        $0.image = UIImage(systemName: "gearshape")
        let twitterAction = UIAction(title: Strings.viewOnTwitter, image: UIImage(named: "twitter.png")) { _ in
            LinkHelper.open(URL.twitter)
        }
        let githubAction = UIAction(title: Strings.viewOnGithub, image: UIImage(named: "github.png")) { _ in
            LinkHelper.open(URL.github)
        }
        let emailAction = UIAction(title: Strings.dropUsALine.withEllipsis, image: UIImage(systemName: "at")) { _ in
            LinkHelper.open(URL.email)
        }
        let shareAction = UIAction(title: Strings.shareInvite.withEllipsis, image: UIImage(systemName: "square.and.arrow.up")) { _ in
            self.showShareActivity()
        }
        let enableSafariAction = UIAction(
            title: Strings.howToEnableSafariExtension, image: UIImage(systemName: "info.circle")
        ) { _ in
            LinkHelper.open(URL.iosSafariGuide)
        }
        $0.menu = UIMenu(
            title: "❤️ " + Strings.tokenary + " ❤️" + Symbols.newLine + "Show love 4269.eth",
            options: [],
            children: [
                twitterAction, githubAction, emailAction, shareAction, enableSafariAction
            ]
        )
        $0.accessibilityIdentifier = "PreferencesBarButtonItem"
        $0.isAccessibilityElement = true
    }
    
    private lazy var cancelBarButtonItem = UIBarButtonItem().then {
        $0.title = "Cancel"
        $0.action = #selector(cancelButtonWasTapped)
        $0.target = self
        $0.accessibilityIdentifier = "CancelBarButtonItem"
        $0.isAccessibilityElement = true
    }
    
    lazy var tableView = UITableView(frame: .zero, style: .insetGrouped).then {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.register(cellWithClass: AccountsListDerivedItemCell.self)
        $0.register(headerFooterWithClass: AccountsListSectionHeaderCell.self)
        $0.tableHeaderView = chainFilterButtonContainer
        $0.tableFooterView = UIView(
            frame: CGRect(x: .zero, y: .zero, width: .zero, height: CGFloat.leastNormalMagnitude)
        )
        $0.dataSource = self.presenter
        $0.delegate = self.presenter
        $0.backgroundColor = .systemGroupedBackground
        $0.accessibilityIdentifier = "TableView"
        $0.isAccessibilityElement = true
    }
    
    lazy var chainFilterButton = UIButton(configuration: .gray()).then {
        var configuration: UIButton.Configuration = .gray()
        configuration.imagePlacement = .trailing
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.title = EthereumChain.ethereum.title
        $0.configuration = configuration
        $0.addTarget(self, action: #selector(chainFilterButtonWasTapped), for: .touchUpInside)
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private lazy var chainFilterButtonContainer = UIView().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // MARK: - Public Properties
    
    var presenter: AccountsListInput
    
    // MARK: - UIViewController
    
    init(walletsManager: WalletsManager, presenter: AccountsListInput) {
        self.walletsManager = walletsManager
        self.presenter = presenter
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDataState(
            .noData, description: Strings.tokenaryIsEmpty, buttonTitle: Strings.addAccount
        ) { _ in }
        setDataStateViewTransparent(true)
        setupViewHierarchy()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationItem.title = presenter.mode == .mainScreen ? Strings.accounts : Strings.selectAccount
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
        switch presenter.mode {
        case .mainScreen:
            navigationItem.rightBarButtonItems = [addAccountBarItemButton, preferencesBarButtonItem]
        case .choseAccount(_):
            navigationItem.leftBarButtonItem = cancelBarButtonItem
            navigationItem.rightBarButtonItem = addAccountBarItemButton
        }
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(light: .white, dark: .black)
        navigationItem.compactAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.standardAppearance = appearance
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.async {
            self.navigationController?.navigationBar.sizeToFit()
        }
    }
    
    // MARK: - Private Properties
    
    private let walletsManager: WalletsManager
    private var toDismissAfterResponse = [Int: UIViewController]()
    
    // MARK: - Private Methods
    
    private func setupViewHierarchy() {
        view.backgroundColor = .white

        view.add {
            tableView
        }
        chainFilterButtonContainer.add(insets: .init(vertical: 4, horizontal: 20)) {
            chainFilterButton
        }
        NSLayoutConstraint.activate {
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            
            tableView.centerXAnchor.constraint(equalTo: chainFilterButtonContainer.centerXAnchor)
            tableView.widthAnchor.constraint(equalTo: chainFilterButtonContainer.widthAnchor)
            tableView.topAnchor.constraint(equalTo: chainFilterButtonContainer.topAnchor)
            
            chainFilterButton.heightAnchor.constraint(equalToConstant: 52)
        }
        view.sendSubviewToBack(tableView)
        
        if !presenter.mode.isPossibleToApplyFilter {
            chainFilterButtonContainer.isHidden = true
            tableView.tableHeaderView?.removeFromSuperview()
            tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        }

        tableView.layoutSubviews()
        
        if presenter.mode != .mainScreen {
            tableView.allowsSelection = false
        }
    }
    
    @objc private func cancelButtonWasTapped() {
        self.presenter.cancelButtonWasTapped()
    }
    
    @objc private func chainFilterButtonWasTapped() {
        let actionSheet = UIAlertController(title: Strings.selectNetwork, message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.sourceView = chainFilterButton
        for chain in EthereumChain.mainnets {
            let action = UIAlertAction(title: chain.title, style: .default) { [weak self] _ in
                self?.didSelect(chain: chain)
            }
            actionSheet.addAction(action)
        }
        let testnetsAction = UIAlertAction(title: Strings.testnets.withEllipsis, style: .default) { [weak self] _ in
            self?.showTestnets()
        }
        let cancelAction = UIAlertAction(title: Strings.cancel, style: .cancel)
        actionSheet.addAction(testnetsAction)
        actionSheet.addAction(cancelAction)
        present(actionSheet, animated: true)
    }

    private func showTestnets() {
        let actionSheet = UIAlertController(title: Strings.selectTestnet, message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.sourceView = chainFilterButton
        for chain in EthereumChain.testnets {
            let action = UIAlertAction(title: chain.title, style: .default) { [weak self] _ in
                self?.didSelect(chain: chain)
            }
            actionSheet.addAction(action)
        }
        let cancelAction = UIAlertAction(title: Strings.cancel, style: .cancel)
        actionSheet.addAction(cancelAction)
        present(actionSheet, animated: true)
    }

    private func didSelect(chain: EthereumChain) {
        chainFilterButton.configuration?.title = chain.title
        self.presenter.didSelect(chain: chain)
    }

    private func showShareActivity() {
        self.showActivityIndicator {
            print("This was done")
        }
        DispatchQueue.global().async {
            let shareVC = UIActivityViewController(
                activityItems: [URL.appStore], applicationActivities: nil
            ).then {
                if UIDevice.isPad {
                    $0.popoverPresentationController?.barButtonItem = self.preferencesBarButtonItem
                }
                $0.excludedActivityTypes = [
                    .addToReadingList, .airDrop, .assignToContact,
                    .openInIBooks, .postToFlickr, .postToVimeo,
                    .markupAsPDF
                ]
            }
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.hideActivityIndicator {
                        print("This was done again")
                    }
                }
                self.present(shareVC, animated: true)
            }
        }
    }
    
    private func didTapCreateNewMnemonicWallet() {
        let chainSelectionVC = ChainSelectionAssembly.build(
            for: .multiSelect(ChainType.supportedChains),
            completion: { [weak self] chosenChains in
                self?.dismissAnimated()
                guard chosenChains.count != .zero else { return }
                let alert = UIAlertController(
                    title: Strings.backUpNewAccount,
                    message: Strings.youWillSeeSecretWords,
                    preferredStyle: .alert
                ).then {
                    $0.addAction(
                        UIAlertAction(title: Strings.ok, style: .default) { [weak self] _ in
                            self?.presenter.createNewAccountAndShowSecretWordsFor(chains: chosenChains)
                        }
                    )
                    $0.addAction(
                        UIAlertAction(title: Strings.cancel, style: .cancel)
                    )
                }
                self?.present(alert, animated: true)
            }
        )
        present(chainSelectionVC, animated: true)
    }
    
    private func didTapImportExistingAccount() {
        let importAccountViewController = instantiate(ImportViewController.self, from: .main)
        present(importAccountViewController.inNavigationController, animated: true)
    }
}

extension AccountsListViewController: AccountsListSectionHeaderEventsRespondable {
    func didTapRemove(wallet: TokenaryWallet) {
        let alert = UIAlertController(
            title: Strings.removedAccountsCantBeRecovered, message: nil, preferredStyle: .alert
        )
        let removeAction = UIAlertAction(title: Strings.removeAnyway, style: .destructive) { [weak self] _ in
            LocalAuthentication.attempt(
                reason: Strings.removeWallet,
                presentPasswordAlertFrom: self,
                passwordReason: Strings.toRemoveAccount
            ) { isSuccessful in
                if isSuccessful {
                    try? self?.walletsManager.delete(wallet: wallet)
                }
            }
        }
        let cancelAction = UIAlertAction(title: Strings.cancel, style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(removeAction)
        present(alert, animated: true)
    }
    
    func didTapRename(wallet: TokenaryWallet) {
        let alert = UIAlertController(
            title: "Rename wallet?", message: nil, preferredStyle: .alert
        )
        alert.addTextField {
            $0.textContentType = .name
            $0.text = wallet.name
        }
        let okAction = UIAlertAction(title: Strings.ok, style: .default) { [weak alert] _ in
            if let newName = alert?.textFields?.first?.text, newName.count != .zero {
                try? WalletsManager.shared.rename(
                    wallet: wallet, newName: newName
                )
            }
        }
        let cancelAction = UIAlertAction(title: Strings.cancel, style: .cancel)
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
        alert.textFields?.first?.becomeFirstResponder()
    }
    
    func didTapReconfigureAccountsIn(wallet: TokenaryWallet) {
        let currentSelection = wallet.associatedMetadata.allChains
        let chainSelectionVC = ChainSelectionAssembly.build(
            for: .multiReSelect(
                currentlySelected: currentSelection,
                possibleElements: ChainType.supportedChains
            ),
            completion: { [weak self] chosenChains in
                self?.dismissAnimated()
                guard
                    chosenChains.count != .zero,
                    chosenChains != currentSelection
                else { return }
                try? self?.walletsManager.changeAccountsIn(wallet: wallet, to: chosenChains)
            }
        )
        present(chainSelectionVC, animated: true)
    }
}

extension AccountsListViewController: AccountsListOutput {
    func didTapExport(wallet: TokenaryWallet) {
        let isMnemonic = wallet.isMnemonic
        let title = isMnemonic ? Strings.secretWordsGiveFullAccess : Strings.privateKeyGivesFullAccess
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: Strings.iUnderstandTheRisks, style: .default) { [weak self] _ in
            LocalAuthentication.attempt(
                reason: Strings.removeWallet,
                presentPasswordAlertFrom: self,
                passwordReason: Strings.toShowAccountKey
            ) { isSuccessful in
                if isSuccessful {
                    self?.showKey(wallet: wallet, mnemonic: isMnemonic)
                }
            }
        }
        let cancelAction = UIAlertAction(title: Strings.cancel, style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    func showKey(wallet: TokenaryWallet, mnemonic: Bool) {
        let secret: String
        if
            mnemonic, let mnemonicString = try? wallet.mnemonic {
            secret = mnemonicString
        } else if let privateKey = wallet[.privateKey] ?? nil {
            secret = privateKey.data.hexString
        } else {
            return
        }

        let alert = UIAlertController(
            title: mnemonic ? Strings.secretWords : Strings.privateKey,
            message: secret,
            preferredStyle: .alert
        ).then {
            $0.addAction(
                UIAlertAction(title: Strings.ok, style: .default)
            )
            $0.addAction(
                UIAlertAction(title: Strings.copy, style: .default) { _ in
                    PasteboardHelper.setPlain(secret)
                }
            )
        }
        
        present(alert, animated: true)
    }
    
    func openSafari(requestId: Int) {
         UIApplication.shared.open(URL.blankRedirect(id: requestId)) { [weak self] _ in
             self?.toDismissAfterResponse[requestId]?.dismiss(animated: false)
             self?.toDismissAfterResponse.removeValue(forKey: requestId)
         }
     }
    
    func presentForSafariRequest(_ viewController: UIViewController, id: Int) {
        DispatchQueue.main.async {
            var presentFrom: UIViewController = self
            while let presented = presentFrom.presentedViewController, !(presented is UIAlertController) {
                presentFrom = presented
            }
            if let alert = presentFrom.presentedViewController as? UIAlertController {
                alert.dismiss(animated: false)
            }
            presentFrom.present(viewController, animated: true)
            self.toDismissAfterResponse[id] = viewController
        }
    }
}
