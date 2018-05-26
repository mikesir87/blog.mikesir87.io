---
layout: post
title: Sign your commits... or else!
category: Blog Post
tags: [git, security]
description: Why's it important to sign your commits? Here's why! And here's how GitHub/GitLab can make things better
excerpt: Why's it important to sign your commits? Here's why! And here's how GitHub/GitLab can make things better
image: /images/signing-key-configured.png
uuid: 8cdd199b-1721-4e1d-ab9a-b61c567e19fd
---

We all understand the importance of authentication and verifying a user before performing actions on a system.  We won't let Alice transfer funds from Bob's bank account.  We won't let Bob create an account using Alice's email address without verifying first (at least most systems verify).  **BUT... we'll let Alice make commits for Bob.**  Wait, what?!?

## A tad bit of background...

Without getting into nitty-gritty details (as I don't know _all_ about [Git internals](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects)), let's take a look at a commit.  The `git log` output shows us a few pieces:

```console
> git log
commit baf5700619886fe3decf7ea8a7305eb8b75f6135
Author: Michael Irwin <mikesir87@gmail.com>
Date:   Fri May 25 18:05:28 2018 -0400

    Added README
```

With this, we see the commit hash, the author, date of the commit, and the commit message.  When I make a commit, the author is set using the machine's configured defaults.  Take a look at your `~/.gitconfig` file to see the current settings:

```plaintext
[user]
        name = Michael Irwin
        email = mikesir87@gmail.com
```

## Let's fake it up!

Looking at how things are configured, there's _literally nothing_ preventing me from faking that and putting someone else's information in. So, let's swap this out to make it look like I'm [Phil Estes](github.com/estesp) (yes... I got permission to spoof him). To make things more realistic, look at recent commits he's made to get the correct name and email address (as most developers have several email addresses).

```plaintext
[user]
        name = Phil Estes
        email = estesp@gmail.com
```

Now, when I make a commit (for example, to add a Dockerfile), I now get git log output like this!

```bash
> git log
commit 578acaf2c711253d14e913b504cf4b019dbea024
Author: Phil Estes <estesp@gmail.com>
Date:   Sat May 26 10:15:46 2018 -0400

    Added Dockerfile (not actually Phil)

commit baf5700619886fe3decf7ea8a7305eb8b75f6135
Author: Michael Irwin <mikesir87@gmail.com>
Date:   Fri May 25 18:05:28 2018 -0400

    Added README
```

So, it _looks_ like Phil made the commit, but it was really me.  Let's go ahead and push this to GitHub and see what we get! Does it link to his profile?

<div class="text-center">
<img src="/images/faked-commits-on-github1.png" style="height: 175px; box-shadow: 0 0 10px #ccc; margin-bottom:10px;" alt="Faked commit on GitHub" />
</div>

**Look at that!  GitHub thinks it's Phil.  It links to his account and, as such, anyone else looking at the commits won't have any way to know it wasn't him!**

You can [check out the repo here](https://github.com/mikesir87/git-spoof-demo).


## Why's this matter?

In this case, I've made it pretty obvious that this commit was not actually by Phil. But, not all others may be as forthcoming. **What's to prevent someone from using social engineering to exploit other people and projects?**  Some possible scenarios:

- Imagine I sent a PR to a repo. Maybe the owner doesn't want the change because I'm unknown and don't have enough clout (terrible, I know!). To raise the likelihood of getting merged, **I could fake some of the commits as someone with more reputation** and then simply say we were working together on it. I would have to hope that the discussion doesn't pull the other party in though!
- When working as a team on a project, **I could throw a colleague under the bus** by making controversial changes using her information.

Overall, this loose metadata makes it really easy to lower the trust of others that commits were made by who is actually indicated. And really, there's no way to _really_ know to untangle the mess other than trusting individuals.


## How to prevent this?

Obviously, the right answer is to **sign your commits**!  By signing your commits, a GPG signature is attached to your commit! Then, if you trust the key is actually owned by the user and assume the user's private key hasn't been compromised, you can _actually verify_ the author of the commit.  I won't reiterate how to setup GPG keys, but here are a few good articles:

- [The GPG Handbook](https://www.gnupg.org/gph/en/manual/book1.html) - a very approachable resource to all things GPG, as well as some of the base concepts of cryptography itself
- [Signing commits with GPG](https://help.github.com/articles/signing-commits-with-gpg/) - a series of posts from GitHub on how to set things up
- [Setting up a YubiKey with GPG](https://github.com/drduh/YubiKey-Guide) - my personal favorite approach and how I use my keys

Once you have your key, run the following to finish things up:

```bash
git config --global user.signingkey "[the last 16 characters of your key fingerprint]"
git config --global commit.gpgsign true
```

If you add the `--show-signature` option when viewing the log, you'll see more details now!

```bash
> git log --show-signature
commit baf5700619886fe3decf7ea8a7305eb8b75f6135
gpg: Signature made Fri May 25 18:05:33 2018 EDT
gpg:                using RSA key 861A2CEB7E8F1E0B70637B278C42FBB0E482C8CF
gpg: Good signature from "Michael Irwin <michael@irwin.tech>" [ultimate]
gpg:                 aka "Michael Irwin <mikesir@vt.edu>" [ultimate]
gpg:                 aka "Michael Irwin <mikesir87@gmail.com>" [ultimate]
Primary key fingerprint: FA3A 9C40 2A4B B77D 705E  EC19 1A24 9025 46BA D019
     Subkey fingerprint: 861A 2CEB 7E8F 1E0B 7063  7B27 8C42 FBB0 E482 C8CF
Author: Michael Irwin <mikesir87@gmail.com>
Date:   Fri May 25 18:05:28 2018 -0400

    Added README
```

If you [associate your GPG key in GitHub](https://help.github.com/articles/adding-a-new-gpg-key-to-your-github-account/), then all commit messages that are signed by you will get the cool "Verified" badge on it.

![Verified badge on GitHub](/images/verified-commit-on-github.png)


## Is this good enough?

Great question!  Right now, GitHub and GitLab only display a badge if the commit is signed. If it's signed by a key configured in the user's settings, it's marked "Verified." If signed by any other key, it's "Unverified."  **What about unsigned commits?**

Here's two small changes we can make to raise awareness of unsigned commits (rather than flat-out banning them)...

### Adding key info on profile pages

It would be nice to know, just by looking at someone's profile if they have a key configured. That way, I can know _immediately_ that the user has a key and I should question things if I see a commit that isn't signed. Sure, an unsigned commit doesn't mean it wasn't them, but I should at least check in.

<div class="text-center">
<img alt="Signing keys configured mockup" src="/images/signing-key-configured.png" style="height:100px;box-shadow: 0 0 10px #ccc" />
</div>

In addition, it would be nice to hover over and get the fingerprints of the configured keys.  They are public keys after all!

[Keybase](https:/keybase.io) helps a ton with this, but not everyone has it connected and publicly displayed. Having GitHub do it by default both makes sense and _should_ be an easy win.


### Adding an "Unsigned" badge

Just as there is a "Verified" or "Unverified" badge when a commit is signed, there should be a "Unsigned" badge when the user has a signing key associated. Again, this doesn't necessarily mean something is wrong (maybe they left their YubiKey somewhere), but it raises awareness.

<div class="text-center">
<img alt="Unsigned badge on commit" src="/images/unsigned-badge-on-commit.png" style="box-shadow:0 0 10px #ccc;" />
</div>

I recognize that this will probably require more work on the part of code repo services, as a lookup has to occur if a user has a key for each commit, rather than responding to the presence of a signature. But, I think it's worth it.  :)

## Conclusion

Don't let Alice fake your commits by signing your commits! With a few adjustments to the largest GitHub and GitLab, we can help users better know if signing is expected and recognize when things aren't quite right.
