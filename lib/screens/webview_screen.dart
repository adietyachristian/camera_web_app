import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewScreen extends StatefulWidget {
  const WebviewScreen({super.key, required this.url});

  final String url;

  @override
  State<WebviewScreen> createState() => _WebviewScreenState();
}

class _WebviewScreenState extends State<WebviewScreen> {
  late WebViewController controller;
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    print("MASUK URL" + widget.url);
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            progressNotifier.value = progress;
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: progressNotifier,
        builder: (BuildContext context, int value, Widget? child) => Scaffold(
              appBar: AppBar(backgroundColor: Colors.black),
              body: value < 100
                  ? LinearProgressIndicator(
                      value: value / 100,
                      backgroundColor: Colors.black,
                      color: Colors.blue,
                    )
                  : WebViewWidget(controller: controller),
            ));
  }
}
