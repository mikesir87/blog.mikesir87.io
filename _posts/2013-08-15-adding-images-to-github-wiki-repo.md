---
layout: post
title: Adding Images to GitHub Wiki Repo 
category: development
tags: [github, images, wiki]
uuid: 30ddc942-e876-44fd-a070-7074bc9e2eec
---


**[Update on April 9, 2014]** – updated URL patterns to reflect change in raw GitHub domain names

Adding images to GitHub is pretty straight forward if you can host the images somewhere or if you can put them into your main repository.  But, what if you want them ONLY in the wiki?  Here’s how to do it!

<!--more-->

1. Clone your wiki’s repository.  The wiki clone url can be obtained by clicking on the “Clone URL” button.

<div class="text-center">
  <a href="/images/wikiImage-1.png"><img src="/images/wikiImage-1.png" alt="Clone URL button on Wiki page" /></a>
</div>

2. Add your image to the repository and push it up.  In this case, I added smiley.png.

<div class="text-center">
  <a href="/images/wikiImage-2.png"><img src="/images/wikiImage-2.png" alt="Clone repo, add image, commit, and push" /></a>
</div>

3. Add the image to your wiki.  The URL will be in the pattern of: https://raw.githubusercontent.com/wiki/[username]/[repository]/[filename]

So, for my example, the image can be loaded from https://raw.githubusercontent.com/wiki/Nerdwin15/imageInWiki/smiley.png.
Hope it helps!  If not, comment and let me know!  You can [see my sample repository here](https://github.com/Nerdwin15/imageInWiki-demo).

