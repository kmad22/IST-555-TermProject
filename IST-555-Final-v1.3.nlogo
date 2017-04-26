;; IST-555
;; Final Project
;; Submitted
;; Trevor Fisher, Adam Duncan, Kevin Madison, Haley McKim, Alexo Smith
;; See the Info tab for documentation, credits, and references.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Variables                                                                  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
globals [
  ;; The list of available obstacles and their corresponding colors.
  obs-shapes
  obs-colors
  ;; A list of all patches on the map used so that they can be reset
  ;; at the end of each call to go.
  patch-list
  ;; The home-base patch
  home-base-patch
]

patches-own [
  ;; This patches parent patch.
  parent
  ;; The total cost of using this patch; f=g+h.
  f
  ;; The cost it took to reach this patch from the start patch.
  g
  ;; The projected cost to reach the destination patch from this patch.
  h
  ;; Marks a patch as occupied or not.
  occupied
  ;; Marks a patch as a destination or not.
  is-destination
  ;; Marks a patch containing litter.
  litter-count
  ;; Marks a patch as the "drone"'s home base.
  home-base
]

turtles-own [
  ;; The turtle's destination patch.
  destination-patch
  ;; The turtles current path to reach its destination.
  path
  ;; Weather the turtle is carrying trash or not
  storage-full
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup                                                                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  ;; Clear everything.
  clear-all
  ;; Initialize the global obstacle shape list.
  initialize-obstacle-lists
  ;; Reset patch-list to be empty
  set patch-list []
  ;; Set up the patches and turtle representing the drone.
  setup-patches
  setup-turtle
  ;; Reset the ticks counter.
  reset-ticks
end

;; Initialize the obstacle shape and color lists.
to initialize-obstacle-lists
  ;;The proportion of each obstacle is
  ;; conerolled by the number of times the symbol is repeated. The color
  ;; of the obstacle is found in the corresponding entry in obs-colors.
  set obs-shapes ["plant" "tree" "tree" "tree pine" "tree pine" "person" "campsite"]
  set obs-colors [ green   green  green  green       green       pink     orange]
end

;; Set up the map for the circle simulation.
to setup-patches
  ask patches [
    ;; Add this patch to the global list of patches.
    set patch-list fput self patch-list
    ;; Mark the patch as not being a destination.
    set is-destination false
    ;; Mark the patch as being unocupied.
    set occupied false
    ;; Mark the patch as having no litter.
    set litter-count 0
    ;; Initialize the home base value.
    set home-base false
  ]
  ;; Spread some litter out over the map
  spread-litter
  ;; Initialize the A* search related patch variables
  reset-patches
end

to spread-litter
  ;; Select litter-patch-count patches and place some litter in them.
  ask n-of litter-patch-count patches with [occupied = false and litter-count = 0 and home-base = false] [
    set litter-count 1
    set pcolor yellow
  ]
end

;; Spawn the "drone" turtle.
to setup-turtle
  ;; Spawn turtles. The first turtle will be the "drone" and be
  ;; stationed at the center of the map. The following turtles
  ;; will be obstacles and be positioned randomly.
  create-turtles num-obstacles + num-drones + 1 [
    ;; A size of 1 makes the most of the current map size.
    set size 1
    ;; Turtle 0 is the home base. Turtles 1 through num-drones are drones.
    ;; All of the following turtles are
    ;; obstacles.
    ifelse who <= num-drones [
      ifelse who = 0 [
        spawn-home-base
      ] [
        spawn-drone
      ]
    ] [
      spawn-obstacle
    ]
  ]
end

;; Spawn the turtle that marks home base.
to spawn-home-base
  ;; Set the base's color go grey.
  set color grey
  ;; Set size to two to make it more visable.
  set size 2
  ;; Set shape to mark it as unique.
  set shape "house ranch"
  ;; Mark the current patch as home base
  ask patch-here [
    set home-base true
  ]
  ;; Set the global home-base-patch to be the patch where the
  ;; home-base turtle is.
  set home-base-patch patch-here
end

;; Spawn a drone
to spawn-drone
  ;; Set color to random to differentiate the drones.
  set color one-of base-colors
  ;; Set the shape to "orbit 6" to resemble a drone.
  set shape "orbit 6"
  ;; Initialize the drone's storage to empty.
  set storage-full false
  ;; Initialize path tot he empty list.
  set path []
  ;; Initialize the drone's destination patch to nobody.
  set destination-patch nobody
  ;; Mark the current patch as occupied. When initialized, multiple
  ;; drones will be in the same place. Once they leave the home
  ;; base, there can be no more than one drone per patch.
  ask patch-here [set occupied true]
  ;; Put the pen in the down position if desired.
  if draw-path [pen-down]
end

;; Spawn an obstacle. Turtles are used to give obstacles unique shapes; some are stationary and
;; others such as people are mobile and drop trash randomly.
to spawn-obstacle
  ;; Set the obstacle turtle's shape to one of the pre-selected shapes.
  set shape one-of obs-shapes
  ;; Set the turtle's color to the appropriate color.
  set color item position shape obs-shapes obs-colors
  ;; Place the obstacle on a random, unocupied, non-home-base patch with no litter on it.
  move-to one-of patches with [occupied = false and litter-count = 0 and home-base = false]
  ;; Set the obstacle's patch to be occupied.
  ask patch-here [set occupied true]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Go Procedures                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  tick
  ;; Have the "drone" navigate.
  ask turtles with [who > 0 and who <= num-drones] [
    ;; Find a destination.
    update-destination
    ;; Set the current patch as being unocupied since the "drone" may move.
    ask patch-here [set occupied false]
    ;; If the turtle is not on its destination patch, prepare to move.
    ifelse patch-here != destination-patch [
      ;; Validate the path.
      if validate-path path = false [
        ;; Run the A* search to generate the turtle's path if the current path
        ;; is no longer valid; it has become blocked or is too short.
        set path a-star-search patch-here destination-patch
      ]
      move-drone
    ] [
      ;; If the current patch is the destination.
      ;; Remove the current destination; it has been reached.
      set destination-patch nobody
      ;; Clear the current path
      set path []
      ;; If the drone is at the disposal site, drop any litter off. Otherwise,
      ;; it is at a patch with litter and can pick some up.
      ifelse patch-here = home-base-patch and storage-full = true [
        dropoff-litter
      ] [
        pickup-litter
      ]
    ]
    ;; Mark the current patch as occupied.
    ask patch-here [set occupied true]
    ;; Reset the patch A* values for the next turtle.
    reset-patches
  ]
  ;; Have the "patron" obstacles wander about randomly.
  ask turtles with [shape = "person"] [
    ;; Have the "patrons" randomly drop some trash.
    drop-litter
    ;; Move randomly.
    wander
  ]
end

;; Randomly spawn some litter on the map.
to drop-litter
  ;; Only spawn litter on 1 in 1000 calls and only if
  ;; there are fewer than 10 litter patches on the map.
  if random 1000 < 1 and remaining-litter < 10 [
    ask patch-here [
      set pcolor yellow
      set litter-count 1
    ]
  ]
end

;; Move a drone to continue along its path or wander randomly
;; if it cannot do so.
to move-drone
  ;; If a path was found, move.
  ifelse not empty? path [
    ;; Face the next destination patch in the list, ie. the second
    ;; one. The first will be the current patch.
    ifelse length path > 1 [
      face item 1 path
    ] [
      face item 0 path
    ]
    ;; If the patch can be moved into, move towards it. Otherwise,
    ;; wander.
    ifelse can-move 0.5 [
      fd 0.5
      ;; If the "drone"'s current patch is in the path,
      ;; remove it.
      if member? patch-here path[
        set path remove patch-here path
      ]

    ] [
      wander
    ]
  ] [
    ;; If a path was not found, wander.
    wander
  ]
end

to pickup-litter
  ;; If the drone is at a patch containing litter, pick it up.
  if [litter-count] of patch-here > 0 [
    ;; Add the trash to the drone's storage.
    set storage-full true
    set color 125
    ;; Mark the patch as no longer containing trash and
    ;; set its color back to black.
    ask patch-here [
      set litter-count 0
      set pcolor black
    ]
    ;; Remove the is-destination flag from the trash containing
    ;; patch.
    set is-destination false
  ]
end

;; Empty a drone's trash storage.
to dropoff-litter
  ;; Drop the litter off.
  set storage-full false
 set color one-of base-colors 
  ;; Update the home-base patch's litter count.
  ask patch-here [
    set litter-count litter-count + 1
  ]
end

;; Find a destination for a "drone"
to update-destination
  ;; If there is no current destination, find one.
  if destination-patch = nobody [
    ;; If the "drone" is empty, find some trash. If it is full, return
    ;; to base to drop the trash off.
    ifelse storage-full [
      ;; If the drone is full, set the destination to home base.
      set destination-patch home-base-patch
    ] [
      ;; If the drone is not full, find a patch with trash or wander randomly if that
      ;; is not possible.
      ifelse remaining-unclaimed-litter > 0 [
        ;; Set the destination patch to be one with litter that is not already a destination or the home base.
        ;; Pick the one that is closest to the drone.
        set destination-patch one-of patches with [litter-count > 0 and home-base = false and is-destination = false] with-min [distance myself]
        ;; Update the chosen patch to mark it as a destination, preventing other drones from choosing it.
        ask destination-patch [
          set is-destination true
        ]
      ] [
        ;; If there is not unclaimed trash, pick a random nearby unoccupied patch as the destination.
        set destination-patch one-of patches in-radius 10 with [occupied = false]
      ]
    ]
  ]
end

;; In the event that a turtle cannot head toward their destination
;; wander randomly until a path is found.
to wander
  ifelse can-move 0.5 [
   fd 0.5
  ] [
   rt random 360
   wander
  ]
end

;; Reset patch A* related variables.
to reset-patches
  ;; Iterate over each patch in the patch-list.
  foreach patch-list [[p] ->
    ask p [
     ;; Reset the patch's parent to nobody.
     set  parent nobody
     ;; Reset f and g to "infinite".
     set f 9999
     set g 9999
     ;; Reset h to zero.
     set h 0
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reporters                                                                  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Report the optimal rout from start-patch to end-patch found using an A*
;; search. Patches are treated as nodes and it is assumed that their f, g, and
;; h values have been reset before this call.
to-report a-star-search [start-patch end-patch]
  ;; If the end patch is occupied, it will not be able
  ;; to find a path, return an emapty list.
  if [occupied] of end-patch = true [
    report []
  ]
  ;; Create the open and closed sets
  let open-set []
  let closed-set []
  let found-path []
  let search-complete false
  ;; Initialize start-patch
  ask start-patch [
    set h distance-between self end-patch
    set g 0
    set f h
  ]
  ;; Push the start patch into the open set
  set open-set fput start-patch open-set
  ;; Iterate while the open set contains patches
  while [length open-set > 0 and not search-complete] [
    let current-patch nobody
    let current-neighbors []
    ;; Sort the open set so that the node with the lowest f value is first
    set open-set sort-by [[patch-one patch-two] -> [f] of patch-one < [f] of patch-two] open-set
    ;; Set current-patch to be the item with the lowest f value
    set current-patch item 0 open-set
    ;; Check if current-patch is the destination-patch. If it is,
    ;; the search is complete and the loop can exit
    if current-patch = destination-patch [
      set search-complete true
    ]
    ;; Pop current-patch from open-set
    set open-set remove current-patch open-set
    ;; Push current-patch into the closed set
    set closed-set fput current-patch closed-set
    ;; Set current-neighbors to current-patch's neighbors
    ;; NOTE: neighbors can be used here instead of neighbors4
    ;; but neighbors4 reduces instances of getting caught on obstacles
    ;; and bouncing around randomly.
    ask current-patch [set current-neighbors sort neighbors4]
    ;; If the search is not done, iterate over the neighbors of current-patch
    if not search-complete [
      ;; Iterate over current-neighbors
      foreach current-neighbors [[neighbor] ->
        ;; If neighbor is not in the closed set or a wall continue
        if not member? neighbor closed-set and [occupied] of neighbor = false [
          ;; Calculate the potential g value of neighbor; current-patch.g + distance-between(neighbor, end-patch)
          let potential-g-of-neighbor ([g] of current-patch) + (distance-between neighbor end-patch)
          ;; If neighbor is not already in the open set, push it on
          if not member? neighbor open-set [
            set open-set fput neighbor open-set
          ]
          ;; Update neighbor if needed
          if [g] of neighbor > potential-g-of-neighbor [
            ask neighbor [
              set g potential-g-of-neighbor
              set h distance-between neighbor end-patch
              set f g + h
              set parent current-patch
            ]
          ]
        ]
      ]
    ]
  ]
  ;; Check if a solution was found and if so, put it in found-path
  if [parent] of end-patch != nobody [
    ;; Add the destination to the path
    set found-path fput end-patch found-path
    ;; Follow the parents back up, adding each new patch to found-path
    let backtrack-parent [parent] of end-patch
    while [backtrack-parent != nobody] [
      set found-path fput backtrack-parent found-path
      set backtrack-parent [parent] of backtrack-parent
    ]
  ]
  ;; Return the resulting path.
  report found-path
end

;; Report the distance between patch-a and patch-b
to-report distance-between [patch-a patch-b]
  report [distance patch-b] of patch-a
end

;; Report whether the caller can move into the patch at distance dist.
to-report can-move [dist]
  ;; Get the result of can-move?
  let clear-to-move can-move? dist
  ;; Check if the destination patch is occupied by a wall or
  ;; another turtle.
  if patch-ahead dist != nobody [
    if [occupied] of patch-ahead dist = true [
      set clear-to-move false
    ]
  ]
  ;; Report whether the caller can move or not.
  report clear-to-move
end

;; Report the amount of litter collected.
to-report litter-collected
  report [litter-count] of patch 0 0
end

;; Report the amount of litter on the map, not counting litter stored at home base.
to-report remaining-litter
  report count patches with [litter-count > 0 and home-base = false]
end

;; Report the amount of unclaimed litter on the map.
to-report remaining-unclaimed-litter
  report count patches with [litter-count > 0 and home-base = false and is-destination = false]
end

;; Determine if a path is still valid; i.e. none of the intermediate patches have become
;; occupied.
to-report validate-path [current-path]
  ;; Check for an empty path; if found, return false.
  if empty? current-path  [
    report false
  ]
  ;; If there is a path, check if the next patch is occupied or not.
  ifelse length path > 1 [
    report not [occupied] of item 1 path
  ] [
    report not [occupied] of item 0 path
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
325
10
1098
784
-1
-1
15.0
1
10
1
1
1
0
0
0
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
125
135
188
168
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
255
135
318
168
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
190
135
253
168
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
5
135
118
168
draw-path
draw-path
0
1
-1000

SLIDER
5
10
177
43
num-obstacles
num-obstacles
0
200
200.0
1
1
NIL
HORIZONTAL

SLIDER
5
50
177
83
litter-patch-count
litter-patch-count
1
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
5
90
177
123
num-drones
num-drones
1
5
5.0
1
1
NIL
HORIZONTAL

MONITOR
210
15
300
60
Litter Remaining
remaining-litter
1
1
11

MONITOR
210
75
300
120
LitterCollected
litter-collected
1
1
11

@#$#@#$#@
IST-555 SD4: Avoiding Pedestrian Collisions
===========================================

## WHAT IS IT?
This is the final project of Team 4 for IST-555 Spring 2017.


## HOW IT WORKS


## HOW TO USE IT


## THINGS TO NOTICE


## THINGS TO TRY


## EXTENDING THE MODEL
There are several ways this model could be extended.
The current A* algorithm is the third iteration of the implementation being used and can likely be optimized for better performance.

At the moment, drones can find trash anywhere on the map and plot a couse to it. This is resource intensive using A* search if the trash if far away. A way to cut down on the distance and therefore the number of steps needed to find a path, drones could be modified to wander randomly and only detect trash within a set radius of themselves. This would mean that the only time they would have to calculate a long path would be when they have to return to home base to drop off their collection from the edge of the map.

Drones currently prioritize finding the piece of trash nearest to them. This could be updated to take how long the piece of trash has been sitting or where the trash is located there into account. If it has been there for a while or is in a high traffic area it could be given a higher priority.

Additional controls could also be added to the map. At the moment, the distribution of obstacle types is random and "patrons" just wander around randomly, dropping trash every once in a while. Additional controls could allow for the fine tuneing of the process.


CREDITS AND REFERENCES
======================
## Base A* Search, Reporter, and Method Implementations
[0] Fisher, T (n.d.). SD4 - Avoiding Pedestrian Collisions

## Documentation Of The A* Search Algorithm And Examples
[1]  Brackeen, D. (n.d.). Game Character Path Finding in Java. Retrieved from Peachpit: http://www.peachpit.com/articles/article.aspx?p=101142&seqNum=2

[2]  codebytes. (n.d.). A* Shortest Path Finding Algorithm Implementation in Java. Retrieved from codebytes: http://www.codebytes.in/2015/02/a-shortest-path-finding-algorithm.html

[3]  Eranki, R. (n.d.). Pathfinding using A* (A-Star). Retrieved from MIT: http://web.mit.edu/eranki/www/tutorials/search/

## NetLogo Example Code Examined For Guidance 
[4]  Singh, M. (n.d.). Astardemo1.nlogo. Retrieved from http://ccl.northwestern.edu/netlogo/models/community/Astardemo1

[5]  Wikipedia. (n.d.). A* Search Algorithm. Retrieved from Wikipedia: https://en.wikipedia.org/wiki/A*_search_algorithm

[6]  YangZhouCSS. (n.d.). roads/GMUroads.nlogo. Retrieved from GitHub: https://github.com/YangZhouCSS/roads/blob/master/GMUroads.nlogo

[7]  NetLogo. (n.d.). Circular Path Example.nlogo. Retrieved from NetLogo Code Examples in the Models Library

[8]  NetLogo. (n.d.). One Turtle Per Patch.nlogo. Retrieved from NetLogo Code Examples in the Models Library


## NetLogo Documentation And Manual
[9]  Izquierdo, L. R. (n.d.). NETLOGO 4.0 - QUICK GUIDE. Retrieved from https://ccl.northwestern.edu/netlogo/resources/NetLogo-4-0-QuickGuide.pdf

[10] NetLogo. (n.d.). Programming Guide - NetLogo 6.0 User Manual. Retrieved from NorthWestern.edu: https://ccl.northwestern.edu/netlogo/docs/programming.html
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

campsite
false
0
Polygon -7500403 true true 150 11 30 221 270 221
Polygon -16777216 true false 151 90 92 221 212 221
Line -7500403 true 150 30 150 225

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

house ranch
false
0
Rectangle -7500403 true true 270 120 285 255
Rectangle -7500403 true true 15 180 270 255
Polygon -7500403 true true 0 180 300 180 240 135 60 135 0 180
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 45 195 105 240
Rectangle -16777216 true false 195 195 255 240
Line -7500403 true 75 195 75 240
Line -7500403 true 225 195 225 240
Line -16777216 false 270 180 270 255
Line -16777216 false 0 180 300 180

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

orbit 1
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 false true 41 41 218

orbit 2
true
0
Circle -7500403 true true 116 221 67
Circle -7500403 true true 116 11 67
Circle -7500403 false true 44 44 212

orbit 3
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 26 176 67
Circle -7500403 true true 206 176 67
Circle -7500403 false true 45 45 210

orbit 4
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 116 221 67
Circle -7500403 true true 221 116 67
Circle -7500403 false true 45 45 210
Circle -7500403 true true 11 116 67

orbit 5
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 13 89 67
Circle -7500403 true true 178 206 67
Circle -7500403 true true 53 204 67
Circle -7500403 true true 220 91 67
Circle -7500403 false true 45 45 210

orbit 6
true
0
Circle -7500403 true true 116 11 67
Circle -7500403 true true 26 176 67
Circle -7500403 true true 206 176 67
Circle -7500403 false true 45 45 210
Circle -7500403 true true 26 58 67
Circle -7500403 true true 206 58 67
Circle -7500403 true true 116 221 67

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tile water
false
0
Rectangle -7500403 true true -1 0 299 300
Polygon -1 true false 105 259 180 290 212 299 168 271 103 255 32 221 1 216 35 234
Polygon -1 true false 300 161 248 127 195 107 245 141 300 167
Polygon -1 true false 0 157 45 181 79 194 45 166 0 151
Polygon -1 true false 179 42 105 12 60 0 120 30 180 45 254 77 299 93 254 63
Polygon -1 true false 99 91 50 71 0 57 51 81 165 135
Polygon -1 true false 194 224 258 254 295 261 211 221 144 199

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

tree pine
false
0
Rectangle -6459832 true false 120 225 180 300
Polygon -7500403 true true 150 240 240 270 150 135 60 270
Polygon -7500403 true true 150 75 75 210 150 195 225 210
Polygon -7500403 true true 150 7 90 157 150 142 210 157 150 7

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
