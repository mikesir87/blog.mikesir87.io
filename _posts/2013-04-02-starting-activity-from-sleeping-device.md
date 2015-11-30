---
layout: post
title: Starting Activity from Sleeping Device 
category: Development
tags: [alarm-manager android wakelock]
uuid: 13a0747d-4a63-4c60-b81a-d4bc54957e09
---


Building off our AlarmManager, we want the ability to have the alarm appear, even if the device is locked. Here’s how.

## Permissions Required
In order to wake up the device, you need to request the WAKE_LOCK permission. To do that, add this XML snippet into your AndroidManifest.xml.

<pre><code class="xml">&lt;uses-permission android:name="android.permission.WAKE_LOCK" /&gt;</code></pre>

## Waking up the Activity Using a Wake Lock
NOTE: We’re building off the code found in [Android – Creating an Alarm with AlarmManager](/2013/04/android-creating-an-alarm-with-alarmmanager/).

Add this to your AlarmReceiverActivity:


<pre><code class="java">private PowerManager.WakeLock wl;
...
public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
    wl = pm.newWakeLock(PowerManager.FULL_WAKE_LOCK, "My Tag");
    wl.acquire();
    ...
    ... //The rest of the onCreate() is still the same (for now)
}

protected void onStop() {
    super.onStop();
    wl.release();
}</code></pre>


So, what we’re doing here is requesting a WAKE_LOCK from the operating system. This lock is a lock on CPU and must be released. That’s why (in this case), I release the lock in the onStop for the activity. Feel free to move it to somewhere else, but you must be sure it gets released.

## Letting the Activity open when Sleeping

In order to let the Activity wake up the device and not require a password/swipe, you only need to add a few flags.

In the old version of the AlarmReceiverActivity, replace:

<pre><code class="java">this.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
    WindowManager.LayoutParams.FLAG_FULLSCREEN);</code></pre>

with this:

<pre><code class="java">this.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN | 
    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD | 
    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED | 
    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
    WindowManager.LayoutParams.FLAG_FULLSCREEN | 
    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD | 
    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED | 
    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);</code></pre>

These flags are pretty self-explanatory, but they do the following:

- **FLAG\_DISMISS\_KEYGUARD** – “when set the window will cause the keyguard to be dismissed, only if it is not a secure lock keyguard.”
- **FLAG\_SHOW\_WHEN\_LOCKED** – “special flag to let windows be shown when the screen is locked.”
- **FLAG\_TURN\_SCREEN\_ON** – “when set as a window is being added or made visible, once the window has been shown then the system will poke the power manager’s user activity (as if the user had woken up the device) to turn the screen on.”


## Wrap-up
That’s all there is to it.  If you want to check out the source code, you can do so [on GitHub here](https://github.com/Nerdwin15/android-waking-up-from-alarm-demo).


