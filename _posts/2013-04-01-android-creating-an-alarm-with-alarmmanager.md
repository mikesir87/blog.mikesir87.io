---
layout: post
title: Android – Creating an Alarm with AlarmManager
category: Blog Post
tags: [alarm-manager, android, wakelock]
uuid: 261ffb34-e639-47bd-94d6-bbd148415bf9
---

There aren’t a lot of good write-ups on how to use the AlarmManager, so here is an example that launches an Activity using the AlarmManager.

<!--more-->

## What’s the AlarmManager used for?

The AlarmManager is used to schedule events or services at either a set time or a set interval. It’s Android’s “version” of the cron. In this case, we’re going to set an alarm for five seconds after the app is launched.

## What we’re going to build
In order to use build this simple app, we’re going to create only two classes. One will be for the Main Activity, and one will be for the Activity we want to launch with the Alarm. We will also have two simple layouts for each of the activities.


### The Main Activity

<pre><code class="java">public class AlarmMainActivity extends Activity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
            this.requestWindowFeature(Window.FEATURE_NO_TITLE);
       setContentView(R.layout.main);

        //Create an offset from the current time in which the alarm will go off.
        Calendar cal = Calendar.getInstance();
        cal.add(Calendar.SECOND, 5);

        //Create a new PendingIntent and add it to the AlarmManager
        Intent intent = new Intent(this, AlarmReceiverActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this,
            12345, intent, PendingIntent.FLAG_CANCEL_CURRENT);
        AlarmManager am = 
            (AlarmManager)getSystemService(Activity.ALARM_SERVICE);
        am.set(AlarmManager.RTC_WAKEUP, cal.getTimeInMillis(),
                pendingIntent);
    }
}</code></pre>


In this Activity, we are setting the layout, setting an offset for five seconds from now, creating the PendingIntent and adding it to the AlarmManager. The PendingIntent.FLAG\_CANCEL\_CURRENT tells the AlarmManager that any other pendingIntent’s with the same id (in this case 12345) should be canceled and replaced with this one. If you want to have more than one alarm, you’ll need to change the 12345 in line 16 to make each alarm unique.

### The AlarmReceiverActivity

<pre><code class="java">public class AlarmReceiverActivity extends Activity {
    private MediaPlayer mMediaPlayer; 

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.requestWindowFeature(Window.FEATURE_NO_TITLE);
        this.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        setContentView(R.layout.alarm);

        Button stopAlarm = (Button) findViewById(R.id.stopAlarm);
        stopAlarm.setOnTouchListener(new OnTouchListener() {
            public boolean onTouch(View arg0, MotionEvent arg1) {
                mMediaPlayer.stop();
                finish();
                return false;
            }
        });

        playSound(this, getAlarmUri());
    }

    private void playSound(Context context, Uri alert) {
        mMediaPlayer = new MediaPlayer();
        try {
            mMediaPlayer.setDataSource(context, alert);
            final AudioManager audioManager = (AudioManager) context
                    .getSystemService(Context.AUDIO_SERVICE);
            if (audioManager.getStreamVolume(AudioManager.STREAM_ALARM) != 0) {
                mMediaPlayer.setAudioStreamType(AudioManager.STREAM_ALARM);
                mMediaPlayer.prepare();
                mMediaPlayer.start();
            }
        } catch (IOException e) {
            System.out.println("OOPS");
        }
    }

    //Get an alarm sound. Try for an alarm. If none set, try notification, 
    //Otherwise, ringtone.
    private Uri getAlarmUri() {
        Uri alert = RingtoneManager
                .getDefaultUri(RingtoneManager.TYPE_ALARM);
        if (alert == null) {
            alert = RingtoneManager
                    .getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            if (alert == null) {
                alert = RingtoneManager
                        .getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            }
        }
        return alert;
    }
}</code></pre>


When this Activity starts, we are ensuring it’s full-screen, playing a sound, and making sure there’s a way to stop the sound. Not too difficult…

Don’t forget to add the Activity to your AndroidManifest.xml


### Layouts

In case you’re new to Android development, these are put into your res/layout folder.

#### alarm.xml

<pre><code class="xml">&lt;?xml version="1.0" encoding="utf-8"?&gt;
&lt;RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="fill_parent"
    android:layout_height="fill_parent"
    android:orientation="vertical"
    android:gravity="center" &gt;

    &lt;Button
        android:id="@+id/stopAlarm"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/stop_alarm" /&gt;

&lt;/RelativeLayout&gt;</code></pre>

#### main.xml

<pre><code class="xml">&lt;?xml version="1.0" encoding="utf-8"?&gt;
&lt;RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:layout_width="fill_parent"
    android:layout_height="fill_parent"
    android:gravity="center"&gt;

    &lt;TextView
        android:id="@+id/test"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/alarm_hello" /&gt;

&lt;/RelativeLayout&gt;</code></pre>


## Wrap-up

Run that and see how it goes! Feel free to leave any comments below!

To check out the source code for this project, you can [find it on Github](https://github.com/Nerdwin15/android-alarmmanager-demo).


