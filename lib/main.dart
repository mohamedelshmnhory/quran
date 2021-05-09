import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitUp,
  ]);
  SharedPreferences pref = await SharedPreferences.getInstance();
  final bool update = pref.getBool("update1") ?? true;
  Directory appDocDirectory;
  if (Platform.isIOS) {
    appDocDirectory = await getApplicationDocumentsDirectory();
  } else {
    appDocDirectory = await getExternalStorageDirectory();
  }
  if (update) {
    final String dirPath = '${appDocDirectory.path}';
    final dir = Directory(dirPath);
    dir.deleteSync(recursive: true);
    pref.clear();
    pref.setBool("update1", false);
    dir.create(recursive: true);
  }
  runApp(MyApp(appDocDirectory));
}

class MyApp extends StatelessWidget {
  final Directory dir;
  MyApp(this.dir);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        fontFamily: 'Tajawal',
      ),
      home: MusicApp(dir),
    );
  }
}

class MusicApp extends StatefulWidget {
  final Directory dir;
  MusicApp(this.dir);
  @override
  _MusicAppState createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  final storage = FirebaseStorage.instance;
  bool playing = false;
  IconData playBtn = Icons.play_arrow;
  IconData modeBtn = Icons.sync_alt;
  String playingTitle = '';
  int playingNum = 1;
  final _player = AssetsAudioPlayer();
  Duration position = Duration();
  Duration musicLength = Duration();
  ScrollController _scrollController = ScrollController();
  bool isInit = true;
  bool downloading = false;
  String i = '';

  void playSound(int soundNumber, {Duration seek}) async {
    SharedPreferences soundInf = await SharedPreferences.getInstance();
    _player
        .open(
      Audio.file('${widget.dir.path}/$soundNumber.wav'),
      showNotification: true,
      notificationSettings: notificationSettings(),
      seek: seek ?? seek,
    )
        .then((value) {
      Future.delayed(Duration.zero, () {
        _scrollController.animateTo(
            (_scrollController.position.maxScrollExtent / 115) *
                (playingNum.toDouble() - 1),
            duration: Duration(milliseconds: 100),
            curve: Curves.linear);
      });
      setState(() {
        playBtn = Icons.pause;
        playing = true;
        playingTitle = title[soundNumber - 1];
        playingNum = soundNumber;
      });
      _player.updateCurrentAudioNotification(
        metas: Metas(
          artist: 'الشيخ أحمد جمال',
          title: playingTitle,
        ),
      );
      soundInf.setString('playingTitle', playingTitle);
      soundInf.setInt('playingNum', playingNum);
    }).catchError((e) {
      if (e.toString().contains('PlatformException(OPEN, null, null, null)')) {
        showAlert();
      }
    });
    _player.current.listen((playingAudio) {
      if (_player.current != null)
        try {
          setState(() {
            musicLength = playingAudio.audio.duration;
          });
          soundInf.setInt('musicLength', musicLength.inSeconds);
        } catch (e) {
          // TODO
        }
    });
    _player.currentPosition.listen((p) {
      setState(() {
        position = p;
      });
      soundInf.setInt('position', position.inSeconds);
    });
  }

  Future<void> downloadList() async {
    File file;
    final listRef = storage.ref().child("new");
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        listRef
            .listAll()
            .then((list) async {
              for (var element in list.items) {
                String filePath = '${widget.dir.path}/${element.name}';
                bool exist = await File(filePath).exists();
                if (!exist) {
                  setState(() {
                    downloading = true;
                    i = element.name;
                  });
                  await storage
                      .ref()
                      .child(element.fullPath)
                      .getData(66666666)
                      .then((bytes) async {
                    file = File(filePath);
                    await file.writeAsBytes(bytes);
                  }).catchError((e) {});
                }
              }
            })
            .then((value) => setState(() {
                  downloading = false;
                }))
            .catchError((e) {
              showAlert();
            });
      }
    } on SocketException catch (_) {}

    // await downloadFile(urls[i], (i + 1).toString()).then((value) async {
    //   if (i < urls.length - 1) {
    //     setState(() {
    //       ++i;
    //     });
    //     await downloadList();
    //   }
    // });
  }

  @override
  void initState() {
    super.initState();
    downloadList().then((_) {
      getInf();
    });
    listenToPlayer();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return WillPopScope(
      onWillPop: () async {
        MoveToBackground.moveTaskToBack();
        return false;
      },
      child: SafeArea(
        child: Scaffold(
          body: downloading
              ? LoadingScreen(i: i)
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.brown[800],
                          Colors.green[200],
                        ]),
                  ),
                  child: Column(
                    children: [
                      buildContainerInfo(size),
                      Center(
                        child: Container(
                          height: size.height * .48,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: ListView.builder(
                              physics: ScrollPhysics(),
                              itemCount: title.length,
                              controller: _scrollController,
                              shrinkWrap: true,
                              itemBuilder: (_, i) {
                                return Container(
                                  color: playingTitle == '${title[i]}'
                                      ? Colors.black38
                                      : Colors.transparent,
                                  child: ListTile(
                                    leading: Text(
                                      '${i + 1} - ',
                                      style: TextStyle(fontSize: 25),
                                    ),
                                    title: Text(
                                      title[i],
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 25),
                                    ),
                                    onTap: () {
                                      playSound(i + 1);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: size.height * .31,
                        padding: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30.0),
                            topRight: Radius.circular(30.0),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: size.height * .075,
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 3),
                              child: Center(
                                child: Text(
                                  playingTitle,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 32.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                                height: size.height * .055,
                                child: Slider.adaptive(
                                    activeColor: Colors.black,
                                    inactiveColor: Colors.grey[350],
                                    value: position.inSeconds.toDouble(),
                                    max: musicLength.inSeconds.toDouble(),
                                    onChanged: (value) {
                                      seekToSec(value.toInt());
                                    })),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(right: 8, left: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "${position.inMinutes}:${position.inSeconds.remainder(60)}",
                                    style: TextStyle(
                                      fontSize: 18.0,
                                    ),
                                  ),
                                  Text(
                                    "${musicLength.inMinutes}:${musicLength.inSeconds.remainder(60)}",
                                    style: TextStyle(
                                      fontSize: 18.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  iconSize: 40.0,
                                  color: Colors.black,
                                  onPressed: () {
                                    if (modeBtn == Icons.sync_alt) {
                                      setState(() {
                                        modeBtn = Icons.shuffle;
                                      });
                                    } else if (modeBtn == Icons.shuffle) {
                                      setState(() {
                                        modeBtn = Icons.repeat_one;
                                      });
                                    } else if (modeBtn == Icons.repeat_one) {
                                      setState(() {
                                        modeBtn = Icons.sync_alt;
                                      });
                                    }
                                  },
                                  icon: Icon(modeBtn),
                                ),
                                IconButton(
                                  iconSize: 40.0,
                                  color: Colors.black,
                                  onPressed: () {
                                    if (playingNum != null)
                                      playSound(playingNum - 1);
                                  },
                                  icon: const Icon(
                                    Icons.skip_previous,
                                  ),
                                ),
                                IconButton(
                                  iconSize: 50.0,
                                  color: Colors.black,
                                  onPressed: () {
                                    //here we will add the functionality of the play button
                                    if (!playing) {
                                      if (playingTitle == '') {
                                        playSound(1);
                                      } else {
                                        if (isInit) {
                                          playSound(playingNum, seek: position);
                                          setState(() {
                                            isInit = false;
                                          });
                                        } else {
                                          _player.play();
                                        }
                                      }
                                      setState(() {
                                        playBtn = Icons.pause;
                                        playing = true;
                                      });
                                    } else {
                                      _player.pause();
                                      setState(() {
                                        playBtn = Icons.play_arrow;
                                        playing = false;
                                      });
                                    }
                                  },
                                  icon: Icon(
                                    playBtn,
                                  ),
                                ),
                                IconButton(
                                  iconSize: 40.0,
                                  color: Colors.black,
                                  onPressed: () {
                                    if (playingNum != null &&
                                        modeBtn == Icons.shuffle) {
                                      playSound(Random().nextInt(title.length));
                                    } else if (playingNum != null &&
                                        playingNum != title.length)
                                      playSound(playingNum + 1);
                                  },
                                  icon: const Icon(
                                    Icons.skip_next,
                                  ),
                                ),
                                IconButton(
                                  iconSize: 40.0,
                                  color: Colors.black,
                                  onPressed: () async {
                                    _player.stop();
                                    setState(() {
                                      playBtn = Icons.play_arrow;
                                      playing = false;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.stop,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  StreamSubscription<bool> listenToPlayer() {
    return _player.playlistFinished.listen((isFinished) {
      if (isFinished && playingNum != title.length && playing != false) {
        if (modeBtn == Icons.sync_alt) {
          playSound(playingNum + 1);
        } else if (modeBtn == Icons.shuffle) {
          playSound(Random().nextInt(title.length));
        } else if (modeBtn == Icons.repeat_one) {
          playSound(playingNum);
        }
      } else if (isFinished && playingNum == title.length && playing != false) {
        playSound(1);
      }
    });
  }

  Container buildContainerInfo(Size size) {
    return Container(
      height: size.height * .169,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundImage: AssetImage(
              'assets/audios/Mishary.jpg',
            ),
          ),
          const SizedBox(width: 15),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                "القارئ الشيخ",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                "أحمد جمال",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> showAlert() {
    return Alert(
      context: context,
      type: AlertType.error,
      title: "تأكد من الاتصال بالانترنت",
      desc: "لتنزيل باقي السور",
      buttons: [
        DialogButton(
          child: Text(
            "خروج",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          onPressed: () {
            Navigator.pop(context);
            downloadList();
          },
          width: 120,
        )
      ],
      onWillPopActive: true,
      closeFunction: () {
        Navigator.pop(context);
        downloadList();
      },
    ).show();
  }

  NotificationSettings notificationSettings() {
    return NotificationSettings(
      customPrevAction: (player) {
        if (playingNum != null) playSound(playingNum - 1);
      },
      customNextAction: (player) {
        if (playingNum != null) playSound(playingNum + 1);
      },
      customStopAction: (player) {
        _player.stop();
        setState(() {
          playBtn = Icons.play_arrow;
          playing = false;
        });
      },
    );
  }

  Future getInf() async {
    SharedPreferences soundInf = await SharedPreferences.getInstance();
    setState(() {
      position = Duration(seconds: soundInf.getInt("position") ?? 0);
      musicLength = Duration(seconds: soundInf.getInt("musicLength") ?? 0);
      playingNum = soundInf.getInt("playingNum") ?? 0;
      playingTitle = soundInf.getString("playingTitle") ?? '';
    });
    if (playingNum != null)
      Future.delayed(Duration.zero, () {
        _scrollController.animateTo(
            (_scrollController.position.maxScrollExtent / 115) *
                (playingNum.toDouble() - 1),
            duration: Duration(milliseconds: 100),
            curve: Curves.linear);
      });
  }

  void seekToSec(int sec) {
    Duration newPos = Duration(seconds: sec);
    _player.seek(newPos);
  }
}

// Future<String> downloadFile(String url, String fileName) async {
//   String dir = widget.dir.path;
//   HttpClient httpClient = HttpClient();
//   File file;
//   String filePath = '$dir/$fileName.wav';
//   // String myUrl = '';
//   bool exist = await File(filePath).exists();
//   if (!exist) {
//     if (mounted)
//       setState(() {
//         downloading = true;
//       });
//     try {
//       // myUrl = url + '/' + fileName;
//       var request = await httpClient.getUrl(Uri.parse(url));
//       var response = await request.close();
//       if (response.statusCode == 200) {
//         var bytes = await consolidateHttpClientResponseBytes(response);
//         file = File(filePath);
//         await file.writeAsBytes(bytes);
//       } else
//         filePath = 'Error code: ' + response.statusCode.toString();
//     } catch (ex) {
//       filePath = 'Can not fetch url';
//       Alert(
//         context: context,
//         type: AlertType.error,
//         title: "تأكد من الاتصال بالانترنت",
//         desc: "لتنزيل باقي السور",
//         buttons: [
//           DialogButton(
//             child: Text(
//               "خروج",
//               style: TextStyle(color: Colors.white, fontSize: 20),
//             ),
//             onPressed: () => SystemNavigator.pop(),
//             width: 120,
//           )
//         ],
//         onWillPopActive: true,
//         closeFunction: () => SystemNavigator.pop(),
//       ).show();
//       print(ex);
//     }
//   }
//   return filePath;
// }
