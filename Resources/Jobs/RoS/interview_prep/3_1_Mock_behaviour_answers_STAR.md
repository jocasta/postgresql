
You’re interviewing for **Database Technical Architect (C1)** at **Registers of Scotland**. That means:

* Strategic thinking
* Risk ownership
* NFR fluency
* Public-sector governance awareness
* Leadership maturity

I’m going to give you **mock behavioural answers** you can model yours on. Don’t memorise them. Internalise the structure and intent.

---

# 1️⃣ Behaviour: Leading Technical Change

**Likely question:**
“Tell us about a time you led a significant technical change.”

### Strong Answer (STAR)

**Situation**
We had a large on-prem PostgreSQL estate supporting critical services, with growing performance issues and infrastructure risk. Hardware was ageing and operational overhead was high.

**Task**
I was responsible for defining a migration path to AWS Aurora while ensuring zero data loss, minimal downtime, and no degradation in service performance.

**Action**

* First, I focused on non-functional requirements: RTO, RPO, throughput, data integrity.
* I created architectural options: lift-and-shift EC2 PostgreSQL, Aurora provisioned, Aurora Serverless.
* I ran cost modelling and operational comparisons.
* We implemented logical replication to enable near-zero downtime cutover.
* I defined rollback plans, test cycles, and failover simulations.
* I engaged security and governance early to ensure audit alignment.

**Result**

* Successful migration with <15 minutes downtime.
* Reduced operational overhead significantly.
* Improved resilience (Multi-AZ + managed backups).
* Clear architectural roadmap for future services.

### Why this works

You:

* Start with NFRs.
* Show structured thinking.
* Show risk mitigation.
* Show measurable outcome.

---

# 2️⃣ Behaviour: Managing Risk in Production

**Likely question:**
“Describe a time you dealt with a major production risk.”

### Strong Answer

**Situation**
A large database was experiencing WAL archiving failures, threatening replication and backup integrity.

**Task**
Prevent data loss and restore operational stability without service disruption.

**Action**

* Assessed replication lag and retention exposure.
* Identified storage saturation as the root cause.
* Implemented immediate mitigation (manual cleanup + temporary capacity).
* Introduced WAL compression and retention tuning.
* Documented lessons and implemented proactive monitoring in Grafana.

**Result**

* No data loss.
* Reduced archive volume long-term.
* Added automated alerting thresholds to prevent recurrence.

### Why this works

Public sector cares deeply about integrity.
You demonstrate calm, structured containment.

---

# 3️⃣ Behaviour: Influencing Without Authority

**Likely question:**
“Tell us about a time you influenced stakeholders.”

### Strong Answer

**Situation**
A product team wanted a fast deployment of a database with minimal HA configuration to save cost.

**Task**
Ensure architecture aligned with resilience standards without blocking delivery.

**Action**

* I reframed the conversation around business impact, not technology.
* Presented cost of downtime vs cost of resilience.
* Offered phased resilience: start with single AZ + defined RTO, move to multi-AZ before production scale.
* Produced simple risk matrix and cost comparison.

**Result**

* Stakeholders agreed to phased architecture.
* Maintained delivery timeline.
* Avoided under-engineered production deployment.

### Why this works

You show:

* Commercial awareness
* Pragmatism
* Governance thinking

---

# 4️⃣ Behaviour: Reducing Technical Debt

**Likely question:**
“Give an example of reducing technical debt.”

### Strong Answer

**Situation**
Multiple PostgreSQL clusters had inconsistent configuration, no version standardisation, and manual deployment processes.

**Task**
Improve maintainability and reduce operational risk.

**Action**

* Standardised configuration templates via Infrastructure as Code (CDK/Terraform).
* Introduced automated patching runbooks.
* Consolidated monitoring dashboards.
* Defined lifecycle policy for engine versions.

**Result**

* Reduced environment drift.
* Faster provisioning.
* Lower operational risk.
* Clear architectural baseline for future projects.

### Why this works

RoS is on a transformation journey. They want debt reduction, not heroics.

---

# 5️⃣ Behaviour: Line Management / Leadership

They will likely probe this.

**Likely question:**
“How do you support and develop technical staff?”

### Strong Answer

**Situation**
Managing DBAs across multiple environments with different skill levels.

**Task**
Improve performance, engagement, and technical maturity.

**Action**

* Introduced structured 1:1s focusing on wellbeing and technical growth.
* Defined skill matrices and personal development goals.
* Encouraged ownership of architectural decisions rather than task execution.
* Created documentation standards and peer review culture.

**Result**

* Increased autonomy within team.
* Reduced escalation dependency.
* Improved retention and morale.

### Why this works

You’re not just technical. You’re enabling others.

---

# Now Let Me Coach You Directly

You are not interviewing as a senior DBA.

You are interviewing as:

* A strategic technical leader
* A risk owner
* A public-sector architect
* Someone who can balance cost, governance, and delivery

When answering:

1. Always mention NFRs early.
2. Always mention risk.
3. Always show structured thinking.
4. Always end with measurable impact.

---

# Next Step

Let’s sharpen you.

I want you to answer this as if you’re in the interview:

> “Tell us about a time you had to make a difficult architectural decision with incomplete information.”

Give me your version.
I’ll critique it like a hiring manager.

[1]: https://chatgpt.com/c/69a4c657-876c-838f-8ab5-7877745c38ca "Case Study Presentation Tips"
[2]: https://chatgpt.com/c/ca5d746c-a0e1-42cf-a683-839d82255365 "Tech Lead Role Responsibilities"
[3]: https://chatgpt.com/c/679c048d-15bc-800f-b650-a6d317cc298e "UK Wind Power Future"
