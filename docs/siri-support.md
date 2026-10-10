# Siri and Shortcuts

Penny uses App Intents. Build metadata confirms eight intents and eight App
Shortcuts on iOS/iPadOS, and two snapshot queries and two App Shortcuts on
watchOS. Siri voice execution has not been tested on hardware.

## iPhone and iPad

These phrases are registered by Penny:

- “How much money do I have left in Penny this month?”
- “How much have I spent in Penny this month?”
- “How much is left for [category] in Penny this month?”
- “How much have I spent on [category] in Penny this month?”
- “Am I over budget in Penny this month?”
- “How much have I saved with Penny this month?”
- “How much have I put toward debt with Penny this month?”
- “Record spending in Penny.”

Category queries use the constrained categories offered by Penny. Recording
spending asks for an amount, description, and category, then requires
confirmation. Arbitrary free-form transaction extraction has not been
validated.

## Apple Watch

Watch offers “How much money do I have left in Penny?” and “How much have I
spent in Penny?” The answer uses the month named in the explicitly shared
snapshot. The intents require local device authentication and do not speak
transaction notes.

Paired Watch transfer and Siri invocation remain untested on hardware.

## Mac and HomePod

macOS supports Penny App Intents through user-created Shortcuts, but not App
Shortcuts. Siri invocation of a custom Mac shortcut is untested.

HomePod can run a user's Siri Shortcuts when Personal Requests are enabled and
configured. Add a Penny shortcut to that collection, then ask Siri to run its
name. Penny's authenticated HomePod path is untested; a locked device may need
to be unlocked before a shortcut that opens an app can continue.

Apple TV does not support App Shortcuts, and Penny does not promise direct Siri
budget queries there.
