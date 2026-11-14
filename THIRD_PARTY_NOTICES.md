# Third-party notices / Mentions tierces

## Dépendances / Dependencies

StatGithub n'embarque **aucun code tiers** : pas de paquet Swift externe, pas de runtime embarqué.
StatGithub bundles **no third-party code**: no external Swift packages, no embedded runtime.

Il utilise uniquement les frameworks fournis par macOS (Apple) :
It only uses frameworks shipped with macOS (Apple):

| Framework | Usage |
|---|---|
| SwiftUI | Interface / user interface |
| Swift Charts | Graphiques / charts |
| Foundation (URLSession) | Requêtes réseau vers l'API GitHub / network requests to the GitHub API |
| Security (Keychain Services) | Stockage du jeton dans le Trousseau d'accès / token storage in the Keychain |
| AppKit | Fenêtre, export CSV / window, CSV export |

Ces frameworks font partie du système et sont soumis aux licences d'Apple ; ils ne sont pas redistribués avec ce dépôt.
These frameworks are part of the operating system, are covered by Apple's licenses and are not redistributed with this repository.

## Service

Les données proviennent de l'[API REST de GitHub](https://docs.github.com/en/rest). L'utilisation de l'API est soumise aux conditions de GitHub.
Data comes from the [GitHub REST API](https://docs.github.com/en/rest); use of the API is subject to GitHub's terms.

## Marques / Trademarks

GitHub, macOS, Apple, Swift et SwiftUI sont des marques appartenant à leurs propriétaires respectifs. **StatGithub est un projet indépendant, non affilié, non approuvé ni sponsorisé par GitHub, Inc. ou Apple Inc.**
GitHub, macOS, Apple, Swift and SwiftUI are trademarks of their respective owners. **StatGithub is an independent project and is not affiliated with, endorsed by or sponsored by GitHub, Inc. or Apple Inc.**
