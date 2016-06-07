---
layout: post
title: Writing Functional Tests with Drone and Graphene that Don't Suck
category: development
tags: [arquillian, drone, graphene]
uuid: b8d5cae1-eb78-40c9-8788-5f489cca056a
---

I've been writing functional tests with Drone and Graphene for a while and have picked up a few "best practices" for myself.  These best practices are designed around **1) make it obvious what you're testing** and **2) use abstractions when available**.  After all...

![Quote meme - Always code as if the guy who ends up maintaining your code will be a violent psychopath that knows where you live](/images/always-code-as-if-the-guy-who-ends-up-maintaining-your-code-will-be-a-violent-psychopath-who-knows-quote-1.jpg)

<!--more-->

## Keep all selector logic in page fragments

> If you find yourself using CSS selectors of ANY sort in your unit test, chances are you you're doing something wrong.

Often, I see tests in which the "how" of the test leaks into the test itself.  Consider the following...

<pre class="no-wrap"><code class="java">public void testTagCloud(@InitialPage HomePage page) {
  page.assertElementDisplayed("#tag-cloud");
}
</code></pre>

What's wrong with that line of code?  It's asserting that an element with id "tag-cloud" is displayed.  However, **the test case is now worrying about the "how"**.  What if the ID changes?  How many different places might need to be updated? Sure, you can put it into a constant.  But, that code actually belongs in the page fragment itself.  If we updated the HomePage class as follows...

<pre class="no-wrap"><code class="java">public class HomePage {
  
  @FindBy(id = "tag-cloud")
  private WebElement tagCloud;
  
  public void assertTagCloudVisible() {
    assertThat(tagCloud.isDisplayed(), is(true));
  }
}
</code></pre>

With that, the "how" of the test is placed where it belongs... in the page fragment.  So...





## Give fragment methods names that make sense

> As with all code, your code becomes an API. As with all APIs, make sure it makes sense.

Let's play **Bad Example, Good Example**.  Here's the bad...

<pre class="no-wrap"><code class="java">public class HomePage {
  public void validateTeaserDisplay(String postName, boolean isDisplayed) {}
  public void validateLoadMoreLinkDisplay(boolean isDisplayed) {}
}
</code></pre>

Why's this bad?  It looks like we're covering the basics.  Looking at the method signature, we can tell what's going on.  In order to see it's flaw, let's look at it in use.

<pre class="no-wrap"><code class="java">public void testTagCloud(@InitialPage HomePage page) {
  page.validateTeaserDisplay("Sample Post", true);
  page.validateLoadMoreLinkDisplay(true);
}
</code></pre>

When seeing it in use, **it's hard to know what's going on by only looking at the code**.  What's the boolean property actually mean?  Have to look back at the method signature.  Ugh...

So, let's make the code more legible by declaring 1) what action is being performed and 2) what object it's being performed on.  Since method's are cheap, split the boolean property into two methods... an assert display and not displayed.

<pre class="no-wrap"><code class="java">public class HomePage {
  public void assertOnPage() {}
  public void assertTeaserDisplayedForPostWithTitle(String postName) {}
  public void assertTeaserNotDisplayedForPostWithTitle(String postName) {}
  public void assertLoadMoreLinkDisplayed() {}
  public void assertLoadMoreLinkNotDisplayed() {}
}
</code></pre>

And let's look at how it's used in a test case.

<pre class="no-wrap"><code class="java">public void testTagCloud(@InitialPage HomePage page) {
  page.assertTeaserDisplayedForPostWithTitle("Sample Post");
  page.assertLoadMoreLinkDisplayed();
}
</code></pre>

Without even looking at the documentation, **it's obvious what each of these methods should do**.  That's the point.  Try NOT to have methods like so...





## Make your fragments chainable

This last little tid-bit is something I like to do because it just makes the test easier to read.  So, let's update our previous HomePage class and add a few methods...

<pre class="no-wrap"><code class="java">public class HomePage {
  public HomePage assertOnPage() {}
  public HomePage assertTeaserDisplayedForPostWithTitle(String postName) {}
  public HomePage assertTeaserNotDisplayedForPostWithTitle(String postName) {}
  public HomePage assertLoadMoreLinkDisplayed() {}
  public HomePage assertLoadMoreLinkNotDisplayed() {}
  public LoginPage clickLoginButton() {}
}
</code></pre>

By changing the return type of every method to ```HomePage```, it allows us to chain the test case together.  Like so...

<pre class="no-wrap"><code class="java">public void testTagCloud(@InitialPage HomePage page) {
  page.assertTeaserDisplayedForPostWithTitle("Sample Post")
      .assertLoadMoreLinkDisplayed()
      .clickLoginButton()
      .setUsername("admin")
      .setPassword("password")
      .clickLogin();
}
</code></pre>

It's not a huge change, but it does help in the readability of the test.  You can quickly scan through the test and see what's going on.
