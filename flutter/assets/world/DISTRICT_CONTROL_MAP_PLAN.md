# Project Arena 1.8.0 — District Control map

## Production priority

The playable map is the first deliverable. Match-loop changes must not be layered over the current 180 × 140 three-lane layout. The current map is a prototype footprint, not the target environment.

## Visual direction

Coastal technology city: a believable, compact city district with a waterfront canal, dense mixed-use blocks, industrial service yards, a civic plaza, a transit interchange and a landscaped park. The palette must separate asphalt, concrete, brick, metal, vegetation and water; avoid an all-green field and avoid a medieval/fantasy silhouette.

## Spatial target

- Logical footprint: 260 × 220 world units, subject to device profiling.
- Five distinct districts: Civic Core, Old Market, Industrial Quay, Transit Exchange and Riverside Park.
- Two asymmetric team compounds on opposite ends, each with multiple exits.
- A connected street graph with at least two loops; no district may be accessible only through a single straight lane.
- Minimum six enterable ground-floor buildings with openings at least 4.8 units wide and interior collision/navigation derived from the same dimensions.
- At least three vertical traversal opportunities, but no mandatory vertical choke point.
- A waterfront route with multiple crossings and traversable promenade edges.
- Landmark sightlines and cover placement must preserve readable combat spaces on a phone-sized screen.

## Gameplay-space rules

- Every major building has an explicit gameplay role and accessible footprint; decorative shells must not be placed where the player expects an entrance.
- Streets, sidewalks, plazas, alleys and interiors are separate navigation surfaces with consistent scale.
- All collision geometry must be authored from the same map definitions as visual placement.
- District objectives are placed at graph junctions or plazas, not in arbitrary empty patches.
- No gathering/crafting/survival loops. District control is the competitive loop.

## Mobile performance budget

- Bake terrain and static environment into offline GLB assets.
- Reuse a small set of CC0 materials and modular meshes.
- Prefer merged static geometry for repeated street dressing where possible.
- Keep dynamic shadows disabled.
- Use distance-based visual detail and avoid loading every interior prop at full detail from the match start.
- Validate sustained frame pacing and temperature on the Realme C53 before raising the asset budget.

## Delivery gates

1. Asset audit: confirm every selected model's source, CC0 license, file hash, scale and triangle count.
2. Greybox: validate map footprint, route graph, spawn safety, traversal, doors and camera readability.
3. Environment pass: replace greybox with pinned CC0 assets, with a unified scale and material palette.
4. Collision pass: verify visual/physics/nav agreement for every building and traversal surface.
5. Device pass: profile load time, memory, frame pacing and thermal behavior on the reference phone.
6. Only then replace the old match loop with District Control objectives that use the actual map topology.
