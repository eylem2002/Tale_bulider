import 'dart:io';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:tale/core/models/file_text_model.dart';
import 'package:tale/core/services/file_service.dart';
import 'package:tale/utils/layout_manager.dart';
import 'package:tale/utils/theme/text_theme.dart';
import 'package:tale/utils/theme/theme_manager.dart';

class DocumentAnalyze extends StatefulWidget {
  const DocumentAnalyze({Key? key}) : super(key: key);

  @override
  State<DocumentAnalyze> createState() => _DocumentAnalyzeState();
}

//ew
class _DocumentAnalyzeState extends State<DocumentAnalyze> {
  // static final Future<JavascriptRuntime> _instance = _initialize();
  FileService fileService = FileService();
  String? msg;
  File? file;
  final Gemini gemini = Gemini.instance;

  List<ChatMessage> messages = [];
  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
      id: "1",
      firstName: "Gemini",
      profileImage:
          "https://seeklogo.com/images/G/google-gemini-logo-A5787B2669-seeklogo.com.png");
  @override
  Widget build(BuildContext context) {
    const Color(0xFF0A061C);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: GradientText(
          'Document Analyze',
          gradient: ThemeManager.title,
          style: TextStyle(
            fontSize: LayoutManager.widthNHeight0(context, 1) * 0.05,
            fontFamily: ThemeManager.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        // actions: <Widget>[
        //   IconButton(
        //     icon: Image.asset(
        //       'assets/images/logo.png',
        //       fit: BoxFit.contain,
        //     ),
        //     onPressed: () {
        //       ///back
        //     },
        //   ),
        // ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: ThemeManager.background,
          ),
        ),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return Container(
      decoration: BoxDecoration(gradient: ThemeManager.background),
      child: DashChat(
          inputOptions: InputOptions(trailing: [
            IconButton(
                onPressed: () {
                  _sendMediaMessage();
                },
                icon: const Icon(Icons.document_scanner, color: Colors.white)),
            IconButton(
                onPressed: () {
                  _sendMediaMessageImage();
                },
                icon: const Icon(Icons.image_search_sharp, color: Colors.white))
          ]),
          currentUser: currentUser,
          onSend: _sendMessage,
          messages: messages),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [
        chatMessage,
        ...messages
      ]; //spread operator --take the messages list and add here

      try {
        String question = chatMessage.text!;
        List<Uint8List>? images;
        if (chatMessage.medias?.isNotEmpty ?? false) {
          images = [File(chatMessage.medias!.first.url).readAsBytesSync()];
        }
        gemini.streamGenerateContent(question, images: images).listen(
          (event) {
            ChatMessage? lastMessage = messages.firstOrNull;
            if (lastMessage != null && lastMessage.user == geminiUser) {
              lastMessage = messages.removeAt(0);
              String response = event.content?.parts?.fold(
                      "", (previous, current) => "$previous ${current.text}") ??
                  "";
              lastMessage.text += response;
              setState(() {
                messages = [lastMessage!, ...messages];
              });
            } else {
              String response = event.content?.parts?.fold(
                      "", (previous, current) => "$previous ${current.text}") ??
                  "";
              ChatMessage message = ChatMessage(
                  user: geminiUser, createdAt: DateTime.now(), text: response);

              setState(() {
                messages = [message, ...messages];
              });
            }
          },
        );
      } catch (e) {
        print(e);
      }
    });
  }

  Future<void> _sendMediaMessage() async {
    String Extraction_text = "";
    bool flag = true;
    FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (pickedFile != null) {
      file = File(pickedFile.files.single.path!);

      try {
        Uint8List fileBytes = await _readDocumentData(file!.path);

        PdfDocument document = PdfDocument(inputBytes: fileBytes);

        PdfTextExtractor extractor = PdfTextExtractor(document);

        Extraction_text = extractor.extractText();
      } catch (e) {
        _showErrorDialog('Error', 'Failed to load the PDF document.');
      }
    } else {
      _showErrorDialog(
          'No File Selected', 'Please select a PDF file to upload.');
    }

    //add the text to the firebase
    if (Extraction_text != "")
      fileService.addFileText(FileTextModel(text: Extraction_text));
    else {
      flag = false;
    }

    if (file != null && flag) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text:
            "I want you to be my data analyst and make a compelling storytelling based on the pdf provided.\n" +
                Extraction_text,
      );
      _sendMessage(chatMessage);
    }
  }

  Future<Uint8List> _readDocumentData(String filePath) async {
    try {
      File file = File(filePath);
      return await file.readAsBytes();
    } catch (e) {
      throw Exception('Failed to read file data: $e');
    }
  } //read from user upload

  // Future<List<int>> _readDocumentData2(String name) async {
  //   final ByteData data = await rootBundle.load('assets/files/sample.pdf');
  //   return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  // } //read from assests folder

  void _showResult(String text) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Extracted text'),
            content: Scrollbar(
              child: SingleChildScrollView(
                child: Text(text),
                physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
              ),
            ),
          );
        });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _sendMediaMessageImage() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
          user: currentUser,
          createdAt: DateTime.now(),
          text:
              "I want you to be my data analyst and make a compelling storytelling based on the image of the chart provided.",
          medias: [
            ChatMedia(url: file.path, fileName: "", type: MediaType.image)
          ]);
      _sendMessage(chatMessage);
    }
  }

  // static Future<JavascriptRuntime> _initialize() async {
  //   final library = await rootBundle.loadString("assets/files/extraction.js");
  //   final runtime = getJavascriptRuntime();
  //   await runtime.evaluateAsync(library);
  //   return runtime;
  // }

  // static Future<dynamic> evaluate(File file) async {
  //   final result = await (await _instance)
  //       .evaluateAsync("extractFirstImageFromPDF('${file}')");
  //   return result.rawResult;
  // }
}
