# User Setup Folder

This folder is the easiest handoff point for a developer or installer setting up ShipyardKit.

## Before you start

Have these ready:

- `shipyardBaseUrl`
- `productSlug`
- `platform`
- the app target you want to modify
- confirmation that the Shipyard product exists and app engagement is enabled
- whether to use the recommended Shipyard layout or a custom app-specific design
- permission to submit a test item during setup

## Fill these first

1. Copy `shipyardkit-config.example.json` to `shipyardkit-config.json` in your app, or map the values into your existing app config.
2. Fill the values for your Shipyard workspace and product.
3. Keep the real config out of git if your workspace URL or notes are private.

## Required values

- `shipyardBaseUrl`
- `productSlug`
- `platform`

## Where to find them in Shipyard

- `shipyardBaseUrl`: open the Shipyard workspace and copy the browser origin. Example: `https://acme-studio.startshipyard.com`.
- `productSlug`: open the product in Shipyard and copy the slug from the URL. Example: `/products/atlas` means `atlas`.
- `platform`: use the Apple platform string for the target app: `ios`, `ipados`, `macos`, `tvos`, `watchos`, or `visionos`.
  If omitted in code, `ShipyardClient` can infer this automatically.

The example values use Acme Corp as the company and Atlas as the product. Replace them before testing a real app.

## Not required

- No static API key.
- No App Store app ID.
- No admin credentials.

The app only needs runtime ability to mint scoped ShipyardKit tokens from Shipyard.

## Shipyard product switches

The public mobile session endpoint rejects disabled products. In Shipyard, make sure:

- the product exists in the Shipyard workspace
- app engagement is enabled for the product

## For installers

Before changing app code, the installer should ask the user for any of these values that are not already obvious in the repo:

- `shipyardBaseUrl`
- `productSlug`
- the correct app target
- the correct config location
- whether to use the recommended Shipyard layout or adapt Announcements, Ask, and Roadmap to the app's existing design
- permission to submit a test item

The installer may infer `platform` from Xcode project files or app sources, but it should tell the user what it found and ask for confirmation before calling setup complete.

## Clean up when done

After setup is complete:

- Keep `ShipyardKit/swift` if Xcode uses it as a local Swift package.
- Remove the copied top-level `ShipyardKit/` handoff folder if the app uses a remote Swift Package URL or the SDK was moved into the app's own package structure.
- Remove copied example config files and one-off setup notes that are not used by the app at runtime.
- Keep final ShipyardKit values in the app's normal config system.
