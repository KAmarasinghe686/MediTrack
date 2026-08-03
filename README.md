# meditrack

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Nearby hospital data

Emergency Mode discovers hospitals within 5 km using OpenStreetMap data and
public Overpass API instances. It does not require an API key. Results are
cached locally for six hours, and a recent cached result is used when the
public Overpass servers are temporarily unavailable.

Hospital data is shown with the required OpenStreetMap contributor
attribution. Public Overpass instances are shared infrastructure, so the app
limits refreshes and automatically tries an alternative endpoint after a
rate-limit or gateway error.
