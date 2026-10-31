# CardPick

CardPick tells you which of your credit cards earns the most at the place you're standing.

It reads your location, asks MapKit for the nearest place, and turns that place into a reward category: dining, gas, groceries, travel, drugstore, or other. It then scores each card in cents per dollar and shows the winner. A shortcut, **Which card here?**, answers the same question from the iPhone Action Button, Siri, or the Shortcuts app.

iOS only lets Apple change the default Apple Pay card. CardPick recommends a card and leaves Wallet alone.

There is no account, no backend, and no analytics. Location stays on the phone. The only third-party tool is XcodeGen, and that runs on your Mac to create the Xcode project. The app itself has no package dependencies.

## What's in the repo

- `CardPick/` — SwiftUI app for iOS 18 and later. Location, MapKit, the main screen, settings, and the App Shortcut live here.
- `Packages/CardPickCore/` — card rules, place-category matching, and the picker. This module does not import UIKit, SwiftUI, or MapKit, so `swift test` runs on Linux and on a Mac without a simulator.
- `project.yml` — the XcodeGen spec. The `.xcodeproj` is generated on your Mac and is not committed.

## Open and run on your iPhone

You need a Mac with current Xcode, and the iPhone signed in to the same Apple ID you use as a Personal Team. This was written for an iPhone 17 Pro Max.

```bash
mkdir -p ~/Projects
git clone https://github.com/balukunju/CardPick.git ~/Projects/CardPick
cd ~/Projects/CardPick
brew install xcodegen
xcodegen generate
open CardPick.xcodeproj
```

Open `CardPick.xcodeproj`, not the folder. The folder also contains a Swift package, and Xcode will open that package instead of the app if you drop the folder on the Dock icon.

In Xcode:

1. Select the **CardPick** scheme.
2. Connect the iPhone, tap Trust on the phone, and choose it as the run destination.
3. Select the **CardPick** target, open **Signing & Capabilities**, and set **Team** to your Personal Team.
4. If Xcode says the bundle id is already in use, change `com.balu.cardpick` to something unique, such as `com.balukunju.cardpick`.
5. Press Run.
6. If the phone says the developer is untrusted, open **Settings → General → VPN & Device Management**, trust your developer certificate, and run again.
7. When CardPick asks, allow location while using the app.

A free Personal Team provisioning profile expires after 7 days. Run the app from Xcode again when it does.

The first build does not download anything. CardPickCore is the local folder `Packages/CardPickCore`.

You can also run in the Simulator. Use **Features → Location → Custom Location** (or a city run) so MapKit has a coordinate to search. The Action Button path is only on a real iPhone.

## Action Button and Siri

1. Run CardPick once on the phone so iOS indexes the shortcut, and allow location.
2. Open **Settings → Action Button**.
3. Swipe to **Shortcut**, tap **Choose a Shortcut**, and choose **Which card here?** under CardPick.
4. If it is missing, open the Shortcuts app, find CardPick under App Shortcuts, run **Which card here?** once, then return to the Action Button settings.

You can also say “Which card here with CardPick”, or run the shortcut from the Shortcuts app.

The shortcut is set to answer without bringing CardPick to the front. After location has been allowed, a press should speak and show a line like:

`Use Robinhood Gold — 3% back at Dining`

The first time, iOS may need you to open the app and allow location. The shortcut cannot show that system prompt on its own. It works best with the phone unlocked.

## Edit your cards

The card list is a JSON file bundled into CardPickCore:

`Packages/CardPickCore/Sources/CardPickCore/Resources/cards.json`

Edit it and rebuild. The running app reads the copy that was compiled in, so a change does not appear until the next build. A later phase can fetch this same shape from a server.

```json
{
  "version": 1,
  "cards": [
    {
      "id": "robinhood-gold",
      "name": "Robinhood Gold",
      "issuer": "Robinhood",
      "rewardType": "cashback",
      "rules": [
        {
          "id": "everything",
          "label": "3% cash back on everything",
          "earn": { "kind": "cashback", "centsPerDollar": 3 }
        }
      ]
    }
  ]
}
```

Fields:

| Field | Meaning |
| --- | --- |
| `rewardType` | `cashback` or `points`. On an equal cents-per-dollar score, the cash-back card wins. |
| `earn.kind` | `cashback` with `centsPerDollar` (3 means 3%), or `points` with `pointsPerDollar`. |
| `categories` | Any of `dining`, `gas`, `groceries`, `travel`, `drugstore`, `other`. Omit it, or leave it empty, if the rule is not tied to a category. |
| `merchants` | Place-name phrases, matched without case or punctuation. `Lyft` matches “Lyft” and “Lyft Hub”. |
| `expires` | Inclusive last day, `YYYY-MM-DD`. Omit it if the offer does not expire. |
| `minimumSpend` | Dollars. The rule counts only when the purchase amount is known and at least this large. |
| `label` | The sentence shown in the app. |

How a card is scored:

1. Expired rules are dropped. A minimum-spend rule is dropped unless the amount is known.
2. A matching merchant offer beats a category offer. A category offer beats a catch-all (no merchant and no category).
3. Points are multiplied by the point value in Settings. Cash back is already in cents per dollar.
4. The higher cents-per-dollar total wins. A tie goes to the cash-back card.

The place screen does not know what you are about to spend, so it passes no amount. The Peloton offer (10x on equipment over $150) therefore stays inactive when you are merely standing at a Peloton. The picker still honors that rule when an amount is supplied. That is covered by the unit tests and is there for a later phase that knows the purchase.

### Seed cards

- **Robinhood Gold** — 3% cash back on everything (3¢ per dollar).
- **Chase Sapphire Reserve** — 3x dining, 4x flights and hotels booked direct, 8x Chase Travel, 5x Lyft through 2027-09-30, 10x Peloton equipment over $150 through 2027-12-31, and 1x everything else.

Travel means flights and hotels, which is what the 4x direct rate covers. An airport or hotel nearby maps to travel. A gas station, grocery, or pharmacy does not. Car rentals stay in Other, because this Sapphire Reserve rule is not a general travel bonus.

Point value is separate from the JSON. Settings stores cents per point on the phone, from 1.0¢ to 2.0¢, default 1.5¢. At 1.0¢, dining is a 3-versus-3 tie and Robinhood wins. At 1.5¢, Sapphire Reserve dining is 4.5¢ per dollar and wins.

## Category mapping

MapKit categories become reward categories inside CardPickCore, so the table is tested without a phone:

| Place | Reward category |
| --- | --- |
| Restaurant, cafe, bakery, brewery, winery, nightlife, distillery | Dining |
| Gas station | Gas |
| Food market | Groceries |
| Pharmacy | Drugstore |
| Hotel, airport | Travel |
| Store, and anything else | Other |

If MapKit names the place Lyft, Peloton, or Chase Travel, the merchant rule is used instead of the category. The category menu on the main screen is for when the lookup is wrong. Choosing a category by hand also ignores the merchant name, since that name came from the same lookup.

## Tests

From a Mac or from Linux, with Swift installed:

```bash
cd ~/Projects/CardPick/Packages/CardPickCore
swift test
```

The tests load the bundled `cards.json` and check the picker directly:

- Dining at 1.0¢ per point is a 3-versus-3 tie, and Robinhood wins.
- Dining at 1.5¢ per point goes to Chase Sapphire Reserve.
- Lyft goes to Chase Sapphire Reserve while the promo is live, including on 2027-09-30.
- The Lyft promo is ignored starting 2027-10-01.
- Gas goes to Robinhood.
- Groceries, drugstore, and anything else go to Robinhood at the default point value.
- Hotels and airports use the 4x direct rate. Chase Travel uses 8x.
- Peloton's 10x applies only with a known spend of at least $150, and not after 2027-12-31.

## Roadmap

- Card catalog on Supabase, so offer changes ship without an app update.
- Statement and email parsing to refresh rotating bonuses.
- Plaid transaction history to learn how merchants actually code.
- A savings dashboard.
- An Apple Watch answer.
- Later, one routing card issued with a partner, so the recommended card is the one that gets charged.

## Privacy

Location is used to find the nearest place and is not uploaded. The point-value setting is stored in User Defaults on the device. Card rules ship inside the app. There is no tracking and no third-party SDK.
