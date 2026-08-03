import 'package:flutter/material.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    ('Your health hub', 'MediTrack keeps your important health information together and ready whenever you need it.', 'assets/images/how_it_works_1_health_hub.png', Icons.dashboard_rounded),
    ('Store medical records', 'Upload lab reports, prescriptions and scans. Search by name or date, switch to grid view, and share the right document quickly.', 'assets/images/how_it_works_2_records.png', Icons.folder_shared_rounded),
    ('Stay on top of medication', 'Add medicines and reminders so you can follow your schedule and keep your treatment organized.', 'assets/images/how_it_works_3_medication.png', Icons.medication_rounded),
    ('Check in and share securely', 'Use hospital check-in, QR access and temporary access to share only what a care team needs.', 'assets/images/how_it_works_4_checkin.png', Icons.qr_code_2_rounded),
    ('Be ready for emergencies', 'Keep your emergency profile current and use SOS to notify your emergency contacts when every second matters.', 'assets/images/how_it_works_5_emergency.png', Icons.health_and_safety_rounded),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How it works')),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 1.02,
                          child: Image.asset(
                            slide.$3,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(slide.$4, size: 76, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Icon(slide.$4, color: Theme.of(context).colorScheme.primary, size: 34),
                      const SizedBox(height: 14),
                      Text(slide.$1, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(slide.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == _page ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == _page ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(8),
              ),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    Navigator.pop(context);
                  } else {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
                child: Text(_page == _slides.length - 1 ? 'Get started' : 'Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
