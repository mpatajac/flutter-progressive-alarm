// TODO: isprobat s _alarmom, doraditi volume change

import 'package:flutter/material.dart';
import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:volume/volume.dart';

AndroidAlarmManager alarmManager;

void alarm() async {
  /// Initalize player
  final audioPlayer = AssetsAudioPlayer();

  /// Start player
  const streamLink = "http://kepler.shoutca.st:8404/";
  try {
    await audioPlayer.open(Audio.liveStream(streamLink));
  } catch (e) {
    /// Use song as a backup
    await audioPlayer.open(Audio("assets/audio/test.mp3"));
    print("Stream not working.");
  }

  _AlarmSetupState.volume();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();

  runApp(ProgressiveAlarm());

  // await AndroidAlarmManager.oneShotAt(time, alarmID, alarm);
}

class ProgressiveAlarm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progressive Alarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AlarmSetup(),
    );
  }
}

class AlarmSetup extends StatefulWidget {
  @override
  _AlarmSetupState createState() => _AlarmSetupState();
}

class _AlarmSetupState extends State<AlarmSetup> {
  bool _alarmSet;
  int _alarmID;
  TimeOfDay _time;
  DateTime _alarmTime;
  static AssetsAudioPlayer audioPlayer;
  static int _initialVolume;

  @override
  void initState() {
    super.initState();
    _alarmSet = false;
    _alarmID = 0;
    _time = TimeOfDay(hour: 9, minute: 0);
    _alarmTime = DateTime.now();
    initAudio();
  }

  void initAudio() async {
    await Volume.controlVolume(AudioManager.STREAM_MUSIC);
    _initialVolume = await Volume.getVol;
  }

  static void volume() async {
    /// Set volume
    ///
    /// Take control of music volume,
    /// save initial volume
    /// and set volume to 1 (minimum)
    int volume = 1;
    await Volume.setVol(volume);

    /// Progressively increase volume
    while (volume < await Volume.getMaxVol) {
      await Future.delayed(const Duration(seconds: 5), () async {
        await Volume.setVol(++volume);
        print("Increasing volume...\n");
      });
    }

    /// Volume fine tuning
    // audioPlayer.setVolume(0.5);

    /// Reset volume and stop the player
    await Future.delayed(const Duration(seconds: 10), () {});
    await Volume.setVol(_initialVolume);
    // await audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('⏰\t\tProgressive Alarm\t\t⏰')),
      ),
      body: Builder(builder: (BuildContext context) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RaisedButton(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                  color: Colors.blue,
                  textColor: Colors.white,
                  child: Text(
                    'Select alarm time',
                    style: TextStyle(fontSize: 28),
                  ),
                  onPressed: () async {
                    TimeOfDay chosenTime = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    setState(() {
                      if (chosenTime != null) {
                        _time = chosenTime;
                        _updateAlarmTime();
                      }
                    });
                  }),
              SizedBox(height: 100),
              Container(
                child: Text(
                  'Toggle alarm:',
                  style: TextStyle(fontSize: 16),
                ),
                height: 30,
              ),
              Transform.scale(
                scale: 2.0,
                child: Switch(
                  value: _alarmSet,
                  onChanged: (bool alarmToggleState) {
                    Scaffold.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          alarmToggleState
                              ? 'Alarm set at ${_formatToastTime()}!'
                              : 'Alarm stopped!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                            letterSpacing: 1.1,
                          ),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                    );

                    _updateAlarmState(alarmToggleState);
                  },
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  String _formatToastTime() {
    int hour = _time.hour;
    int minute = _time.minute;
    return '${_fixLeadingZero(hour)}:${_fixLeadingZero(minute)}';
  }

  String _fixLeadingZero(int number) {
    return number < 10 ? '0$number' : '$number';
  }

  void _updateAlarmState(bool startAlarm) async {
    if (startAlarm) {
      await AndroidAlarmManager.oneShotAt(_alarmTime, _alarmID, _alarm);
    } else {
      if (_didAlarmStart()) {
        await Volume.setVol(_initialVolume);
        await audioPlayer.stop();
      } else {
        await AndroidAlarmManager.cancel(_alarmID);
      }
    }

    setState(() {
      _alarmSet = startAlarm;
    });
  }

  bool _didAlarmStart() {
    DateTime now = DateTime.now();
    if (now.day < _alarmTime.day) {
      return false;
    }
    if (now.hour < _alarmTime.hour) {
      return false;
    }
    if (now.minute < _alarmTime.minute) {
      return false;
    }
    return true;
  }

  void _updateAlarmTime() {
    DateTime now = DateTime.now();
    DateTime alarmTime = new DateTime(
        now.year,
        now.month,
        _time.hour >= now.hour ? now.day : (now.day + 1),
        _time.hour,
        _time.minute);

    setState(() {
      _alarmTime = alarmTime;
    });
  }

  static void _alarm() async {
    /// Initalize player
    audioPlayer = AssetsAudioPlayer();

    /// Start player
    const streamLink = "http://kepler.shoutca.st:8404/";
    try {
      await audioPlayer.open(Audio.liveStream(streamLink));
    } catch (e) {
      /// Use song as a backup
      await audioPlayer.open(Audio("assets/audio/test.mp3"));
      print("Stream not working.");
    }

    volume();
  }
}
