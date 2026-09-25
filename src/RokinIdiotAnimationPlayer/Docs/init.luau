--[[
RokinIdiotAnimationPlayer — Documentation

Plays animations made in the RokinIdiot editor inside your game.
Values are computed and applied by the same modules the editor preview uses,
so what you see in Studio is what runs in game.

(한국어 문서는 이 폴더의 "한국어" 모듈에 있습니다.)


────────────────────────────────────────────────────────────────────────────
Quick start
────────────────────────────────────────────────────────────────────────────

const AnimationPlayer = require(ReplicatedStorage.RokinIdiotAnimationPlayer)

const track = AnimationPlayer:LoadAnimation(save, character, sword)
track.Looped = true
track:Play(0.3)

track:GetMarkerReachedSignal("Impact"):Connect(function()
    hitbox:Fire()
end)

require returns a single, already-created service. There is no need to call
new. Creating several would split priority arbitration so they could not see
each other.


────────────────────────────────────────────────────────────────────────────
save — what to pass
────────────────────────────────────────────────────────────────────────────

The StringValue made by  Menu → Export Animation to Workspace  in the editor.
Move it somewhere like ReplicatedStorage and pass it in.

Accepted:

  StringValue          the exported value itself
  Folder / Model       a StringValue is searched for inside it
  string               the JSON string itself


────────────────────────────────────────────────────────────────────────────
Items — choosing what moves
────────────────────────────────────────────────────────────────────────────

In the editor every item has a number. Put the real object in that slot.

  AnimationPlayer:LoadAnimation(save, character, sword)
  -- 1 = character, 2 = sword

If the numbers have gaps (you deleted item 2, leaving 1 and 3), pass a table.

  AnimationPlayer:LoadAnimation(save, { [1] = character, [3] = sword })

Numbers you do not pass are simply skipped. No warning, no error, because
passing only some items on purpose is common. The skipped numbers are listed
in track.MissingItems.


────────────────────────────────────────────────────────────────────────────
AnimationPlayer
────────────────────────────────────────────────────────────────────────────

:LoadAnimation(save, ...) -> RokinIdiotAnimationTrack
    Creates a track. Does not play it. Set properties, then call :Play().

:GetPlayingTracks() -> { RokinIdiotAnimationTrack }
    Tracks currently playing. Tracks fading out are included.

:StopAll(fadeTime: number?)
    Stops every playing track.

:Destroy()
    Stops everything and restores every value that was touched.


────────────────────────────────────────────────────────────────────────────
RokinIdiotAnimationTrack — properties
────────────────────────────────────────────────────────────────────────────

Shaped like Roblox's AnimationTrack. Assigning a property fires Changed and
GetPropertyChangedSignal.

Read only

  .Animation      : StringValue?   the save this track plays
  .IsPlaying      : boolean        true while fading out too
  .Length         : number         total length (seconds)
  .Speed          : number         change with :AdjustSpeed()
  .WeightCurrent  : number         current weight
  .WeightTarget   : number         weight it is moving towards
  .MissingItems   : { number }     item numbers that got no instance

Read / write

  .Looped         : boolean        wrap from the end to the start (default false)
  .Priority       : number         who wins on overlap (starts at the save's value)
  .TimePosition   : number         assign to jump to that time
  .Restore        : boolean        restore original values on stop (default true)
  .FireMarkers    : boolean        fire marker signals (default true)

Markers inside a range skipped with TimePosition do not fire. The playhead
moved there; it did not pass through.


────────────────────────────────────────────────────────────────────────────
Playing backwards
────────────────────────────────────────────────────────────────────────────

A negative speed plays backwards.

  track:Play(0, 1, -1)
  track:AdjustSpeed(-1)

When looped it passes 0 and wraps to the end. Otherwise it ends at 0.
This matches how Roblox documents AnimationTrack.Looped.

While going backwards, keyframes, markers and methods do not fire. Rewinding
must not play sounds or effects again.

Calling :Play() on a stopped track with a negative speed starts from the end.
Roblox stays frozen on the last frame there until the track is reloaded; that
is not copied.


────────────────────────────────────────────────────────────────────────────
RokinIdiotAnimationTrack — methods
────────────────────────────────────────────────────────────────────────────

:Play(fadeTime: number?, weight: number?, speed: number?)
    Plays. Defaults: 0, 1, current speed.
    With fadeTime the weight rises from 0 to the target over that time.
    Each start re-reads where the origin item stands, so a track loaded
    earlier still plays from where the character is now.

:Stop(fadeTime: number?)
    Stops. Stopped fires immediately. With fadeTime the values are not
    released at once; Ended fires when the weight reaches 0 and the values are
    restored then. IsPlaying stays true meanwhile.
    Calling Stop again while fading out only changes the fade time.

:AdjustSpeed(speed: number?)
    Changes the speed. Defaults to 1.

:AdjustWeight(weight: number?, fadeTime: number?)
    Changes the target weight, moving there over fadeTime.

:GetMarkerReachedSignal(name: string) -> Signal
    Fires when a marker with that name is passed. The same name returns the
    same signal. Names that do not exist yet are created too.

:GetTimeOfKeyframe(name: string) -> number?
    Time of a named point in seconds, or nil. Roblox throws here, but an
    animation is data that may be fixed later; stopping game logic over a name
    is worse.

:Destroy()
    Stops and cleans up signals.


────────────────────────────────────────────────────────────────────────────
RokinIdiotAnimationTrack — signals
────────────────────────────────────────────────────────────────────────────

.DidLoop          ()               finished one loop
.KeyframeReached  (name: string)   passed a named point
.Stopped          ()               playback ended
.Ended            ()               no longer touches anything
.Changed          (property, value) any property changed

Stopped and Ended differ. Stopped fires first when playback ends; Ended fires
when the fade-out is done and the track really lets go. Roblox's AnimationTrack
uses the same order.

  track:Stop(0.5)
  -- Stopped  immediately
  -- Ended    0.5 seconds later

Without a fade they fire back to back.


────────────────────────────────────────────────────────────────────────────
Keyframes and markers
────────────────────────────────────────────────────────────────────────────

In the editor you can name points in time and put several markers inside.
When the playhead passes such a point they fire in this order.

  1. KeyframeReached once, with the keyframe name
  2. GetMarkerReachedSignal(markerName) once per marker

Only when moving forward. Rewinding or jumping with TimePosition does not fire
them, so sounds and effects never play twice.

Priority and weight do not matter. They fire even at weight 0.2 — they are
events, not state. You cannot call :Emit() 0.2 times.


────────────────────────────────────────────────────────────────────────────
Position tracks and the origin item
────────────────────────────────────────────────────────────────────────────

Item positions are saved relative to the origin item chosen in the editor.
The origin's current position is read once when :Play() starts and used for
the whole run. Reading it every frame would drift while the origin itself is
being moved.

If another track is already moving the origin item, its original position
(before any animation touched it) is used instead.


────────────────────────────────────────────────────────────────────────────
Overlapping animations
────────────────────────────────────────────────────────────────────────────

When two animations touch the same property of the same object:

  1. Only the highest Priority number is kept
  2. What remains is blended by weight

Blendable values (number, CFrame, Color3, Vector3 ...)
    Averaged by weight. If the total weight is below 1, the object's original
    value fills the rest, so a fade-in starts smoothly from the original look.

Non-blendable values (boolean, string, EnumItem, Instance)
    There is no half-enabled particle. Only tracks whose weight reached 1 set
    the value, and if several did, the one that started first wins. During a
    fade-in the value is not set yet; during a fade-out it is held until the
    weight reaches 0.


────────────────────────────────────────────────────────────────────────────
Restoring on stop
────────────────────────────────────────────────────────────────────────────

Touched values are restored when the track stops. Otherwise a particle turned
on would stay on. Set Restore to false to keep the final state.

The value restored is the one the property had when any track first touched
it. If two tracks touched it, the first one saw the real original.

A value is restored only on the frame nobody touches it anymore. If the winner
still holds it, the loser stopping changes nothing.

Once restored, the remembered original is forgotten. If your game changes that
property later, the next animation starts from (and restores to) the new value.


────────────────────────────────────────────────────────────────────────────
Where to run it
────────────────────────────────────────────────────────────────────────────

The client is recommended. It works on the server, with two differences:

  - Every property change replicates. Changing a particle every frame is
    network traffic, and it grows with the number of players.
  - Motor6D.Transform does not replicate at all. Rig poses played on the
    server are invisible to other players.

So cutscenes with rigs must run on the client. Let the server announce
"play this cutscene now" and have each client play it locally. The remote for
that belongs to your game; this package does not create one.

Everything steps on RunService.Heartbeat, which runs after the default
Animator in the frame, so rig poses written here are what gets rendered.
Heartbeat also exists on the server, unlike BindToRenderStep.


────────────────────────────────────────────────────────────────────────────
Troubleshooting
────────────────────────────────────────────────────────────────────────────

Nothing happens
    Items may not have been passed. Check track.MissingItems.
    A wrong path silently skips only that track — check that the path under
    the item in the editor matches the real object.

The rig does not move
    Make sure it is not running on the server. Motor6D.Transform does not
    replicate.

Values do not come back
    Check that Restore is not false, and that a higher-priority track is not
    still holding the property.
]]

return nil
