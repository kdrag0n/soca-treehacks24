# Soca

*Seeing through your ears*

## Inspiration

We came across this idea by thinking about underutilized modalities. Albert was on the long bus ride to TreeHacks Friday morning, scrolling through a list of sensors in various Apple devices. Spatial audio stuck out to us as an underexplored mixed-reality interface that could encode a lot of information and create intuitive natural experiences, especially for those who are missing other senses. 

Vision loss is a really big problem (that’s only getting worse, from first hand experience). Soca is unobtrusive and uses off-the-shelf hardware that we all already happened to have. We’re also really excited to see what other people do with the other sensors hiding in plain sight. 

Once we began to think about this as a mixed reality interface design problem, we realized there’s so much more we can do. From needfinding, we know that finding stuff is really hard when you can’t see. Instead of groping around, imagine asking “where’s my blue T-shirt” or “where’s the sign for gate C3”?

## What it does

Soca transforms visual surroundings into auditory landscapes, to help the visually impaired see the world. We use LiDAR-camera data to find the real-world location of obstacles and points of interest, then point them out with spatial audio. This way, you can navigate around obstacles and towards goals just by listening to the virtual sounds around you. See from your ears, through your phone camera, to the visual world.

## How we built it

We use the built-in Apple LiDAR and camera streams to detect obstacles and task objectives, then create localized virtual speakers to orient the user. To perform object detection, we pre-process cluster the point cloud and fine-tuned SegmentEverything. The objects and depth are then converted into xyz world coordinates. Once objects are found, we embed audio cues using spatial localization -- you can “hear” where the objects are located (imagine 3D stereo audio).

To construct the scene geometry, we use ARKit to capture a depth map from LiDAR scanning and create the virtual reality environment. We use the AVFoundation audio engine to play spatial audio, with object and point-of-interest detection using LiDAR data clustering and SegmentEverything. We experimented heavily with many parts of the pipeline—fields of view, clustering vs segmentation algorithms, and vision models from classic ssd image recognition to gpt4v (which didn’t work, amazingly enough), and various spatial audio transforms (HRTF, equal power pairing), and sound profiles, to optimize localization. Other than the on-device component, we use Bun for the debug and inference server, for real time analysis and debugging. 

## Challenges we ran into

Transforming from the depth coordinates, to VR world coordinates, and finally to speaker orientation and Airpods was difficult—we learned loads about camera intrinsics, transform matrices, and the hazard of non-commutative operations :) In addition, spatial audio was also challenging to debug—sometimes “whether it’s working” was so subjective. Finally, we got some good practice getting models running (reinstalled conda twice!) and iterating on prompts as quickly as possible. We were amazed that SegmentAnything ended up being better than GPT4-vision, which we (and all the mentors we talked to) had expected to be the one-shot solution.

## Accomplishments we're proud of

Actually being able to walk around with our eyes closed.  We were able to validate that this approach of spatial audio works for navigation, and works well. It was also extremely exciting to explore the potential of this untapped data modality for enhancing how we interface with the world.

## What we learned

Intuitive interfaces are hard to build—they can be very powerful if done correctly, but they tap into a low-level part of the brain so if you get one thing slightly wrong from the real physical model, then things feel off. Eg. pure tones and beeps don’t work, but we’re really great at detecting voices and music.
Even if a project seems easy, you must get to the iterative debugging stage as quickly as possible. We were very confident in the beginning but ended up not having an MVP until 5am today. 
Coordinates/pose transforms are hard—one must think carefully! Especially because composing rotations is non-commutative, and we are dealing with { camera, world, AR scene, and listener } coordinate spaces. 

## What's next for Soca

We are iterating with user feedback and implementing additional features for spatial audio navigation. Expanding to more sophisticated capabilities would enable things like:

- Exploring a city through real-time navigation. Imagine “Take me to the nearest coffee shop” and following non-intrusive audio cues and ambient signals for directions, instead of having to stare at your phone
- Enhanced object recognition capabilities, such as tracking objects through time + OCR. This will detect and dictate signs, give context for locations and surroundings, and help identify items, enabling the visually impaired to fully navigate the signposted world. 
- Integration with an LLM agent for specific queries and searching in a scene -- “find me the blue T-shirt” and reasoning about “we need to collect more information by going here, or interacting with this object” 
- Plane detection for floors and walls (ARkit), overhead detection for branches
/ more direct path detection. Denoting sidewalk/floor edges with noise walls, special sound effects for things like stairs, streets, escalators, and elevators 
