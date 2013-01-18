---
layout: default
title: JSON Framework 2.0!
---

**Update:**
<a href="http://devblog.brautaset.org/2008/08/30/json-framework-21/">Version 2.1</a> of this framework has now been released.

Version 2.0 of the Objective-C JSON framework has been released!

I received no ill words about the 2.0 pre-release, so have decided to relabel it 2.0 and get it out there. It is now the recommended version of this framework. Here are the major changes in this release compared to 1.2, the previous stable release:

<ul>
<li><strong>Methods return nil rather than throw exception on bad input</strong>

The existing API looks the same on the surface but in the case of failure will now log an error to the console and return <code>nil</code>, rather than throw an exception. This to adhere to the <a href="http://developer.apple.com/ReleaseNotes/Cocoa/RN-ObjectiveC/index.html#//apple_ref/doc/uid/TP40004309-DontLinkElementID_11">Cocoa guidelines</a> of only throwing exceptions on programmer errors. </li>

<li><strong>New underlying API returning NSError in case of failure</strong>

The <a href="http://code.brautaset.org/JSON/interface_s_b_j_s_o_n.html">new lower-level API</a> optionally returns an NSError object via a parameter. A lot of work has gone into making the error reporting more accurate. For example, we now report "trailing comma not allowed in dictionary" rather than "invalid JSON".</li>

<li><strong>Consolidated formatting options</strong>

For simplicity the SpaceBefore, SpaceAfter, and MultiLine formatting options have been rolled into the new HumanReadable option. The Pretty and MultiLine options&mdash;though they continue to function as aliases to HumanReadable&mdash;are now deprecated.

<li><strong>Xcode-integrated API documentation</strong>

Having switched to <a href="http://www.stack.nl/~dimitri/doxygen/">Doxygen</a> for generating API docs, I got Xcode&nbsp;3 integration for free. This lets you search the JSON API information directly from within Xcode. To install it open the .dmg and, in Terminal.app, cd into the <code>html</code> folder it contains and type <code>make install</code>. </li>


</ul>

Version 2.0 continues to be supported for Mac OS X Tiger. It has been developed and tested using Xcode, but since it is a Foundation framework it should work fine on <a href="http://gnustep.org/">GNUstep</a>.

<h3>Resources</h3>

<ul>

<li>Visit the <a href="http://code.google.com/p/json-framework/">project home page</a> on Google Code</li>
<li>Download the <a href="http://json-framework.googlecode.com/files/JSON_2.0.dmg">embedded framework and API documentation</a></li>
<li>View the <a href="http://code.brautaset.org/JSON/">API docs</a> online</li>
<li>Browse <a href="http://code.google.com/p/json-framework/source/browse/tags/2.0">the source</a> online </li>
<li>Check out the source from this <a href="http://json-framework.googlecode.com/svn/tags/2.0/">Subversion tag</a></li>
</ul>
