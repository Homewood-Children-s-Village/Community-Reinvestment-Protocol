# The Village Demo Day Memo

| Project Name | The Village  |
| :---- | :---- |
| Founders | Homewood Children’s Village in partnership w/ Jomari Peterson |
| Website | hcvpgh.org |
| Socials | https://x.com/hcvpgh |
| Tech Doc | https://docs.google.com/document/d/e/2PACX-1vQkrA-Knwt8215rmSKtViYeSyw2fPBDRA3DGIbBifL93FLpIPYWEmzwgD7jsWS4fc1zcB6FevDy2nvf/pub |
| GTM Strategy | https://docs.google.com/document/d/e/2PACX-1vQkrA-Knwt8215rmSKtViYeSyw2fPBDRA3DGIbBifL93FLpIPYWEmzwgD7jsWS4fc1zcB6FevDy2nvf/pub |
| Code Repo | https://github.com/Homewood-Children-s-Village/Community-Finance-Protocol |
| Other links | [*https://youtu.be/GynEFlUCy4o*](https://youtu.be/GynEFlUCy4o) *[https://docs.google.com/presentation/d/1yYPmG\_vtxXBqbGbliO13nVWpvC\_kdutEhv098Txlrn8/edit?usp=sharing](https://docs.google.com/presentation/d/1yYPmG_vtxXBqbGbliO13nVWpvC_kdutEhv098Txlrn8/edit?usp=sharing)*  |

*This **Demo Day Memo** is a concise narrative document summarizing your project’s story, traction, and opportunity for presentation purposes. If a section is present in either your **Technical Architecture Document** or your **GTM Strategy Document**, summarize the key takeaways and insights most relevant to Demo Day from them. Whenever a section connects directly to content from either of those documents, add a hyperlink or reference.*

## **One-Liner**

*A single sentence that clearly summarizes what your company does or enables.*

The Village turns local service into on-chain community power by converting verified service hours and contributions into transparent funding for real neighborhood investment and revitalization..

## **Problem**

*Describe the core pain point or inefficiency in the market. Explain who experiences it, why it matters, and what the current consequences are*

* *What problem exists in the market?*  
* *Who experiences it, and why is it urgent to solve it?*  
* *What’s broken or inefficient about current solutions?*

Community organizations struggle to connect participation to tangible community progress. Volunteers contribute time, businesses offer support, and homeowners face urgent needs, yet the value created across these efforts remains disconnected, untracked, and hard to channel into revitalization. Without tools that unify service, rewards, and reinvestment, staff feel overwhelmed, residents feel unseen, and neighborhoods struggle to build sustained momentum.

## **Competitive Landscape**

*Summarize existing solutions and why they fall short. Identify categories: incumbents, emerging competitors, or indirect alternatives. How is your approach different or better?*

**Categories of existing solutions**

* **Web3 impact and grants platforms**  
  Examples include Gitcoin-style grants and impact projects on Celo. They are strong at routing crypto donations and running grant rounds, but they usually stop at funding distribution. They do not connect day to day service, family level stabilization, and specific neighborhood assets like distressed homes into one loop.  
* **Crypto donation platforms**  
   Platforms like The Giving Block or Endaoment help donors route digital assets to nonprofits and get receipts. They optimize for fundraising campaigns rather than ongoing, measurable ties between service, credits, and local project outcomes.  
* **Traditional nonprofit CRMs and volunteer tools**  
   Salesforce NPSP, custom ERPs, and volunteer scheduling tools help track contacts, hours, and grants, but they are siloed databases. They do not provide verifiable on-chain flows, shared ownership primitives, or a native way to translate service and aid into neighborhood level investment signals. Staff remain buried in manual reporting.

**Why they fall short**

* They separate volunteering, funding decisions, and community projects instead of treating them as parts of a single economic loop.  
* They provide limited transparency for residents and local partners about where value actually goes, which erodes trust over time.  
* They rarely give communities reusable, open infrastructure they can adapt for their own governance and reinvestment strategies.

**How The Village is different**

The Village is intentionally designed as a full loop system for one neighborhood first, with four pillars in one stack: immediate emergency stability, the ability to serve and earn, long term wealth building via fractionalized projects, and shared governance. Rather than being a generic DeFi product, it is built in partnership with Homewood Children’s Village, a long-standing anchor institution, and then abstracted so other communities can copy the architecture.

## **Solution**

*Describe your product or protocol and how it solves the problem differently or better.*  
*Highlight what’s technically or conceptually unique (architecture, UX, integrations, or business model).*

* *What is the product, and how does it work at a high level?*  
* *What makes it technically or operationally defensible?*

The Village is an Aptos based toolkit that connects three things that are usually separate:

1. A **service ledger** where community leaders define activities like food preparation, tutoring, and cleanups, and staff approve service hours. Approved hours mint a controlled on-chain credit, the Time Dollar, that are transferred to community members..  
2. A **community reinvestment fund** that receives those credits and, in later phases, stablecoins, and attributes them as impact shares in specific projects such as stabilizing inherited homes on a target block.  
3. **Dashboards and project views** that let staff, residents, and homeowners see how service and contributions are flowing into real projects with clear goals and visible progress.

During Assembly, the focus is on proving the smallest loop: HCV staff configure activities, residents log hours, staff approve and mint credits on Aptos, and those credits are redeemed into symbolic impact shares in a real project that everyone can see.

**How it works at a high level**

* Privy handles onboarding, light identity, and embedded wallets.  
* Move modules on Aptos handle Time Dollar minting, community project registries, contribution accounting, and impact share records.  
* A minimal backend and indexer layer listens to on chain events and turns them into human readable timelines and project views.

**What makes it defensible**

* **Anchor first, protocol second:** Designed with and for HCV’s real operations, not as a speculative protocol in search of a user. This produces workflows that other organizations can adopt with minimal change.  
* **On chain core logic with restricted flows:** Time Dollars and fractional shares are implemented as permissioned digital assets with KYC gating and role based minting, which reduces abuse and keeps the system compatible with regulatory guardrails.  
* **Template for replication:** Contracts, patterns, and UX are structured so other neighborhoods, faith networks, and nonprofits can adopt the same architecture with their own branding and governance, turning The Village into reusable impact infra for Aptos.

## **Market Size**

*Estimate your Total Addressable Market (TAM) and, if relevant, Serviceable or Obtainable Market. Why is this market growing or ripe for disruption? Include relevant metrics (volumes, growth rates, user bases)*

The Village operates at the intersection of three underdigitized economies: volunteer service, community philanthropy, and neighborhood revitalization.

In the U.S., residents contribute roughly 4–5 billion volunteer hours a year, valued at about 120–167 billion dollars, and donate around 499 billion dollars annually to charities. On top of that, programs like Opportunity Zones have already attracted 100 billion dollars plus in investment for place-based development. Globally, government and NGO spending on housing and community amenities reaches into the hundreds of billions each year. This is the Total Addressable Market (TAM) The Village can help coordinate and verify, by turning service hours, aid flows, and local projects into a unified, trackable ledger.

Our Serviceable Available Market (SAM) focuses on institutions capable of actually running this kind of system: an estimated 4,450 to 6,680 multiservice human service organizations in the U.S., plus a broader ring of hundreds of thousands of nonprofits and faith-based groups that already manage volunteers, emergency aid, or neighborhood projects. Together, they control tens of billions of dollars in annual grants, donations, and program budgets that are currently tracked across siloed tools.

Our Serviceable Obtainable Market (SOM) assumes modest early penetration: if The Village helps digitize even 0.1–1 percent of U.S. volunteer hours and routes a similar fraction of revitalization capital through community funds and fractionalized projects, that represents on the order of hundreds of millions to low billions of dollars in validated Time Dollars, contributions, and project flows. Given the current momentum around RWA tokenization, DAO-style governance, crypto philanthropy, and nonprofit digitization, this is a market that is not just large, but structurally ready for a purpose-built protocol like The Village.

*.*

## **Target Customers**

*Briefly define your core users or customers; who they are, what motivates them, and why they’ll switch or adopt. Include Primary and Secondary segments if relevant. Summarize your key insight about this audience that others might have missed. Link to your GTM Strategy document section where you explain in more depth*

The Village is intentionally designed around real institutions and real residents, not abstract wallets.

**Primary institutional customers**

1. **Anchor Community Institutions**   
    Multiservice community based organizations and human service nonprofits with budgets above 500,000 dollars and at least a small full time staff. These organizations are asked to do everything at once: mobilize volunteers, distribute aid, coordinate programs, and report outcomes across siloed systems. Their core pain is the accountability gap between all the activity they manage and the ability to show a verifiable, asset level story of neighborhood progress. The Village offers them an integrated ledger of service hours, community funds, and project milestones that turns their operations into an auditable economic loop instead of scattered spreadsheets.

2. **Faith Based Networks and Large Ministries**  
    Large churches, urban ministries, and regional faith networks that mobilize thousands of volunteers and control meaningful balance sheets, but lack infrastructure to connect service, giving, and real community assets. Globally, major faith based institutions steward an estimated 5 trillion dollars in assets, with only a small fraction intentionally deployed in impact. The Village gives them a compliant way to reward service with Time Dollars, direct capital into verified projects such as home stabilization, and demonstrate that their congregational energy translates into concrete neighborhood outcomes.

**Secondary institutional customers**

3. **Municipal and Quasi Government Agencies**  
    City agencies, housing authorities, and redevelopment authorities that manage distressed properties and public funds. Their primary need is clear, verifiable evidence that community members have a stake in and are benefiting from publicly funded projects. The Village acts as a blended finance verification layer, recording resident Time Dollar contributions and co investment alongside city dollars or Opportunity Zone capital.

**End user customer archetypes**

4. **Local Community Members / Volunteers**  
    Residents who already serve but feel that their hours are invisible and disconnected from real change. For them, the protocol provides immediate Time Dollar recognition and a visible link between their hours and a specific project, such as a neighbor’s house moving toward repair. That feedback loop is designed to counter the national pattern where roughly one in three volunteers do not return the following year.

5. **Distressed Homeowners and Community Members**  
   Homeowners in disinvested neighborhoods who are rich in community ties but poor in cash and credit. They are seeking a path to stabilize their homes without predatory debt or displacement. The Village allows them and other community members to formalize their needs as a project, watch service hours and funds accumulate, and sign a clear community contract that codifies shared expectations and protections.

**Key insight**

Most tools either manage donors and contacts, route crypto donations, or help governments track projects. Very few, if any, treat service hours as on-chain inputs, tie them directly to real world assets, and expose that entire loop in a way that community members can actually understand. The Village’s protocol is designed around that loop.

## **Traction / Metrics**

*Show evidence of progress or validation. If pre-launch, outline upcoming milestones (e.g., alpha, beta, partnerships).*

* *Current usage, volume, or revenue.*  
* *Growth rates, retention, or engagement metrics.*  
* *Early partnerships, pilots, or feedback from key users.*

**Foundational traction**

* The protocol has been co-designed with Homewood Children’s Village, a multiservice anchor with over a decade of operations and deep trust in the Homewood neighborhood.  
* HCV’s real operating data already validates the volume potential: 21,157 service hours logged in a recent two year period, which at 34.79 dollars per hour represents roughly 736,000 dollars of social capital that could have been minted as Time Dollars and routed into neighborhood projects.  
* Technical architecture, Move module design, UX flows, and low fidelity wireframes have been completed for the core loop: KYC, service validation, Time Dollar minting, project registry, impact shares, and community fund flows.

**90 day milestones**

Over the next 90 days, The Village will:

* Deploy the initial Time Dollar, project registry, and impact share modules on Aptos testnet.  
* Integrate KYC and abstracted gas so non-technical residents can participate without handling APT directly.  
* Launch a controlled pilot with HCV staff, volunteers, and at least one distressed homeowner project.

Pilot success metrics will include:

* At least 100 verified service hours logged on-chain.  
* 1 to 2 pilot projects funded to a clear milestone, such as a specific repair stage on a distressed home.  
* 50 or more unique wallets activated across staff, volunteers, and residents.  
* First Time Dollar redemptions and impact shares issued and visible in a resident facing interface.

**Ongoing KPIs**

Looking beyond the pilot, the core metrics that matter are:

* Service volume: total verified hours and Time Dollars minted and redeemed.  
* Capital volume: project capital managed per year and AUM across community funds and fractionalized projects.  
* Organizational adoption: number of anchor institutions onboarded, moving from 1 HCV to 3 to 5 replication pilots and eventually 20 plus organizations in a network deployment.  
* Financial performance: implementation revenue per organization and AUM style fees on revitalization flows such as Opportunity Zone aligned projects.

## **Team**

*List key team members with brief, relevant experience that demonstrates capability to win this market*

**Walter Lewis, President and CEO, Homewood Children’s Village**  
Over 15 years in nonprofit management, leads HCV’s strategy, cross sector partnerships, and fundraising. Under his leadership HCV has raised and managed over $25M and serves 1,400+ youth annually.

**Jomari Peterson, System Architect**  
Web3 strategist and system architect with experience deploying DeFi systems that have managed hundreds of millions in assets, designing DAOs with sustainable revenue, and building inclusive lending and fractional housing tools. Author of “Faith & Cryptocurrency,” focused on mission aligned Web3 infrastructure.

**Dr. John M. Wallace Jr., Board President**  
Pastor, professor, and civic convener with deep experience in research, urban ministry, and social innovation, strengthening the project’s institutional credibility and neighborhood legitimacy.

**Key HCV staff support**

* Erica Lewis, Senior Manager, Family & Community Engagement  
* Raymond Robinson, Sr. Director of Programs  
* Becky Dupree, Controller (finance and compliance)

Together, the team combines deep local trust and program operations with advanced blockchain, governance, and product design experience tailored to community organizations.

## **Go-to-Market**

*Explain how you’re acquiring and retaining users or customers.*

* *Key growth loops, partnerships, and acquisition channels.*  
* *Short-term launch strategy and longer-term scalability plan.*

The Village’s go-to-market strategy starts from one deeply rooted neighborhood and scales outward as a repeatable civic finance pattern, not just another software rollout.

#### **Near-term: Lighthouse pilot in Homewood**

Our first priority is to turn Homewood into a “lighthouse implementation” with Homewood Children’s Village (HCV). The goal is to prove the full loop in a single neighborhood: service hours recorded, Time Dollars minted, community funds deployed, and real-world projects moving toward visible milestones.

In the first 90 days we will:

* Deploy The Village with HCV staff, volunteers, and at least one distressed homeowner.  
* Run a closed pilot that validates the full loop from service to impact shares.

Success metrics for this phase:

* At least **2** projects funded to a clear milestone.  
* At least **100** verified service hours logged on-chain.  
* At least **75** Time Dollar redemptions.  
* At least **50** unique wallets interacting with the system.  
* One fully documented case study that shows the story from “Marcus volunteers” to “Tanya’s home is stabilized.”

This gives us both operational proof and narrative proof: a concrete example Aptos, HCV, and other partners can rally around.

#### **Turning the pilot into a playbook**

Once the loop works in Homewood, the focus shifts to turning it into a playbook and an ecosystem story rather than a one-off project.

We will:

* Package the pilot into a set of repeatable templates: onboarding flows, governance patterns, Time Dollar policies, and RWA project configurations.  
* Work with Aptos Foundation on co branded content:  
  * Blogs, AMAs, and Demo Day talks.  
  * Short “before/after” stories that make the protocol legible to foundations, DAOs, and city partners.  
* Share the implementation guide with other Aptos ecosystem teams building in impact, RWA, or civic tooling so they can integrate or co sell.

The playbook becomes the bridge from “this works in Homewood” to “this works in any neighborhood with the right anchor.”

#### **Expansion: faith and community networks**

For scale, we target networks that already concentrate trust, people, and purpose: churches, faith based nonprofits, and community coalitions.

Our next wave focuses on:

* **3–5 additional pilots outside Pittsburgh**, targeting:  
  * Children’s Village style models in other cities.  
  * Large urban ministries and faith networks.  
  * Housing or neighborhood coalitions that already coordinate multiple organizations.  
* Using warm introductions from HCV and partners rather than cold outreach.  
* Showing how the same protocol can be tuned to different local contexts while preserving the core loop.

Over time, this evolves into city or region level deployments where a foundation, municipality, or network sponsor underwrites implementation across a cluster of organizations using The Village as shared infrastructure.

#### **Channels**

We will acquire and activate users through a mix of direct engagement and ecosystem leverage:

* **Direct, on-the-ground activation**  
  * Work directly with HCV staff and programs to onboard residents, volunteers, and homeowners.  
  * Host small in person and virtual sessions to walk people through earning Time Dollars and seeing project progress.

* **Network and convening channels**  
  * Warm introductions through HCV’s peers (Children’s Zone models, urban ministries, human service alliances).  
  * Presence at conferences and convenings in:  
    * Community development and CDFIs.  
    * Philanthropy and impact investing.  
    * Faith based social impact.

* **Web3 and Aptos ecosystem channels**  
  * Co marketing with Aptos Foundation and key infra partners (wallet, KYC, and stablecoin providers).  
  * Showcasing The Village as a flagship “real-world impact on Aptos” use case in ecosystem updates, social channels, and events.

#### **Growth and retention loops**

Retention and growth are built into the structure of the protocol, not just the marketing plan.

* As projects reach visible milestones, residents see a direct line between:  
  * Their hours of service,  
  * The Time Dollars they earn, and  
  * Tangible changes in their neighborhood (a repaired home, a funded project).  
     This closes the “I volunteered, but nothing changed” loop that burns out volunteers.

* Each successful pilot produces:  
  * A verified data trail of service, funds, and impact.  
  * A story that funders and peer organizations can trust.  
     This social proof lowers acquisition costs for the next anchor institution and supports sponsored, city wide deployments.

* Shared infrastructure on Aptos creates a flywheel:  
  * As more deployments go live, it becomes more attractive for foundations, DAOs, and RWA funds to route capital through The Village.  
  * Each new capital partner increases the value of being a participating organization, making the network harder to replace.

In short, we start with one neighborhood, turn that into a proof and a playbook, and then scale through high trust networks and sponsored civic deployments, with Aptos as the shared settlement and verification layer underneath.

## **FAQ**

*Include 3–6 concise questions that preempt doubts.*

* *Common topics:*  
* *Security, regulatory, or technical risk*  
* *Competition or defensibility*  
* *Market timing*  
* *Monetization*  
* *Scalability or partnerships*

**1\. How do you handle security and on chain risk for vulnerable communities?**  
Core economic logic lives in Move modules. Time Dollars and impact shares are permissioned assets with role based minting and restricted transfer rules. No personally identifiable information is stored on-chain; identity and KYC are handled off-chain via providers like Privy, Persona or local staff, with only write approved addresses into a compliance registry.

**2\. Are fractional shares securities, and how do you avoid regulatory issues?**  
In the initial pilot, impact shares are treated as symbolic or restricted rights rather than freely tradable yield instruments. Transfers are constrained to program flows, and participation is framed as community engagement and accountability rather than speculative investment. Over time, with legal support, the same architecture supports KYC gating, role-based access, and restricted transferability to align with local counsel and regulatory expectations.

**3\. Why won’t a generic grants platform or CRM solve this instead?**  
Most existing tools either move money or log activities. They do not connect service, aid, and neighborhood assets into one visible loop, nor do they expose verifiable flows that residents, staff, and funders can share. The Village is designed specifically to unify these flows for neighborhood revitalization and to run as shared infrastructure across multiple organizations on Aptos.

**4\. How do you make this adoptable for non technical organizations?**  
Onboarding is designed around familiar concepts: activities, hours, projects, and family cases. Privy abstracts wallet management, and the frontend uses simple dashboards rather than Web3 jargon. HCV and future partners receive implementation and training support, and the architecture minimizes backend complexity so local teams do not have to operate heavy infrastructure.

**5\. What is the long term monetization plan?**  
Short term deployments are funded by grants and philanthropic partners. Long term, The Village earns from implementation and training fees for new organizations, small basis point fees on managed capital pools in later RWA phases, and sponsored city or network deployments where foundations or agencies underwrite platform rollouts across multiple neighborhoods.

**6\. Why is Aptos the right chain for this?**  
Move’s resource model and Aptos’s performance profile are well suited for permissioned assets, fine grained access control, and auditable flows without excessive gas overhead. Aptos Assembly support and ecosystem partners provide both capital and technical guidance, and the resulting architecture is intended as an Aptos first reference implementation for service backed community finance.

