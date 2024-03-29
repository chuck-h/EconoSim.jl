# Agent based simulation for local economics and oswap federation

Chuck (SEEDS) and Stef (Happonomy) have discussed using Stef’s EconoSim simulation framework to investigate local currency system behavior.

Ref: https://www.happonomy.org/ , https://github.com/HapponomyOrg/EconoSim.jl 

EconoSim is an ABM (agent-based modeling) package written in the Julia language and based on the Agents.jl package. Agents.jl is popular and actively maintained. Stef has used EconoSim for several different economic modeling inquiries since 2021, but it has not, to date, been used by other researchers.

## Modeling goals for local economics 

We would like to be able to model a small scale economy (village to bioregion) employing a complementary currency. Participants (individuals and small businesses) transact in both the ordinary national currency and the complementary local currency. We will examine simulated value flows among different types of participants (e.g. farmers, laborers, bakers, restaurants), which are represented as individual “agents” or “actors” in the simulation software. We are also interested in value flows to and from the world outside the community boundary. Value flows include goods, services, local currency, and national currency.

The simulation consists of a series of events over time, involving agents, entities (goods), and currency. Most of these events are one-to-one transactions between participants: Alice buys something from Bob. Other events may independently affect a person’s possessions: a farmer’s crops grow, or a grocer’s produce spoils. Producing agents execute actions which transform value types: a baker uses labor and grain to produce bread. Each “agent” expresses certain behavior patterns as to choosing what actions to take. Different product types also have behaviors described by blueprints.These behaviors are written as computer code; it is a delicate issue to write behavior code that is simple enough to be feasible and complex enough to capture aspects which are important to the simulation.

In connection with the LoREco project EconoSim has implemented behavioral code for production and sale of products, damage and repair, waste  production, and several other features. Also, the EconoSim Balance Sheet structure can represent assets and liabilities denominated in both local and national currencies. This existing tool set can serve as a template for our local-economy simulation work. Some additional considerations:
EconoSim does not enumerate behaviors for labor and services distinct from physical goods. This may need refinement.
The purchase/sale behaviors should include constraints like “up to half of the invoice may be paid in local coins”.
Agents who exchange currency (e.g. an office which sells and redeems local currency for cash) need to be implemented.
We will want to identify the behavioral differences between agents inside and outside the community boundary.

Here are two types of analysis to perform on these economic models:
Stability analysis. As we simulate a continuing stream of events over time, does the system “settle down” or does it oscillate in boom-and-bust cycles? If it does settle down, how does it respond to a “chock”: a sudden change in a system parameter?
Sensitivity analysis. If we “tune” behavior functions, currency incentives, or other parameters, can we achieve systematic shifts in economic performance (e.g. more “circularity”)?
We anticipate that the simulation will include pseudorandom influences on the agents’ decisions and the entities’ status. It will take several repetitions of the simulation, without changing the scenario, to get a meaningful result as an average of the repetitive simulation runs. We will want to randomize the sequence of agent execution; otherwise “first-mover” advantage will fall to the same agent on every time step.

## Modeling goals for inter-community trade 

We would like to simulate a more complex situation in which several local economies, with individual local currencies, trade goods and services with one another.

We can create several instances of the local economy model described above. We need to simulate a new function: foreign exchange transactions denominated in local currencies. The foreign exchange agent could implement the “oSwaps” AMM algorithm, or fixed exchange ratios, or other behaviors.

In this simulation we can experiment with stability and sensitivity analysis regarding foreign trade parameters.



