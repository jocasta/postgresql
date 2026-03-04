Good move asking for more. Behavioural interviews at that level can easily run **8–12 questions**, so the more scenarios you have ready the better.

I’ll give you **additional ones that are very typical for UK public-sector architecture roles** like the **Registers of Scotland C1 post**. These lean heavily on **risk, governance, resilience, and stakeholder management**.

---

# 6️⃣ Behaviour: Handling a Major Incident

**Likely question**

> “Tell us about a major service incident and how you handled it.”

### Example structure

**Situation**
A production database supporting a critical service began experiencing severe performance degradation during peak hours.

**Task**
Restore service quickly while identifying the root cause and preventing recurrence.

**Action**

* I first prioritised service restoration by isolating long-running queries causing lock contention.
* Implemented temporary workload throttling while we analysed the issue.
* Identified a missing index introduced by a recent release.
* Coordinated with the development team to deploy a safe index creation strategy without blocking writes.
* After stabilisation, conducted a full post-incident review.

**Result**

* Service restored within the incident window.
* Introduced improved release testing and query monitoring.
* Implemented automated alerting for similar patterns.

### Why this question matters

They want to see:

* **calm under pressure**
* **structured response**
* **learning from incidents**

---

# 7️⃣ Behaviour: Balancing Cost vs Resilience

This one is **very likely** for RoS.

**Likely question**

> “Describe a time you had to balance cost with resilience or reliability.”

### Example structure

**Situation**
A team wanted to reduce infrastructure costs for a database platform by simplifying the architecture.

**Task**
Ensure cost reductions didn’t compromise availability requirements.

**Action**

* Assessed business impact of downtime with stakeholders.
* Identified which services truly required **high availability** and which could tolerate longer recovery times.
* Proposed tiered resilience architecture:

  * critical systems → Multi-AZ deployment
  * lower-risk workloads → simpler configuration with defined recovery procedures

**Result**

* Reduced overall infrastructure cost.
* Maintained resilience where required.
* Clear architectural standards for future services.

---

# 8️⃣ Behaviour: Challenging a Technical Decision

Architect roles often require **pushing back**.

**Likely question**

> “Tell us about a time you challenged a technical decision.”

### Example structure

**Situation**
A project proposed deploying a new database platform quickly without proper backup and disaster recovery design.

**Task**
Ensure the system met organisational standards for data protection.

**Action**

* Engaged with the project team to understand delivery pressures.
* Explained the operational and regulatory risks of insufficient backup strategy.
* Proposed a pragmatic solution that could be implemented quickly but still met minimum standards.
* Worked with the team to incorporate automated backups and restore testing.

**Result**

* Project proceeded on schedule.
* Platform met organisational resilience standards.
* Avoided introducing long-term operational risk.

---

# 9️⃣ Behaviour: Improving Observability / Monitoring

Given your background, this is an **easy win**.

**Likely question**

> “Describe a time you improved monitoring or operational visibility.”

### Example structure

**Situation**
Our database estate had limited visibility into performance issues and capacity trends.

**Task**
Improve operational monitoring and proactive detection.

**Action**

* Introduced centralised metrics collection.
* Built dashboards showing key indicators such as query performance, replication lag, and storage utilisation.
* Defined alert thresholds to detect emerging issues early.
* Worked with operations teams to integrate alerts into incident response processes.

**Result**

* Faster detection of issues.
* Reduced time to resolution.
* Improved confidence in platform reliability.

---

# 🔟 Behaviour: Delivering Through Collaboration

Public sector loves **collaboration language**.

**Likely question**

> “Tell us about a time you worked across teams to deliver a complex solution.”

### Example structure

**Situation**
A migration project required coordination between infrastructure, application teams, security, and operations.

**Task**
Ensure the migration could proceed safely without disrupting services.

**Action**

* Established regular technical working groups.
* Clarified responsibilities and risks across teams.
* Ensured architecture decisions were documented and understood.
* Ran testing and rehearsal exercises before production cutover.

**Result**

* Successful migration delivered collaboratively.
* Reduced organisational risk.
* Stronger cross-team relationships.

---

# 1️⃣1️⃣ Behaviour: Learning from Failure

Very common behavioural question.

**Likely question**

> “Tell us about a time something didn’t go as planned.”

### Example structure

**Situation**
A database upgrade introduced unexpected performance regression after deployment.

**Task**
Stabilise the system and understand what had gone wrong.

**Action**

* Performed immediate rollback to restore stability.
* Investigated the root cause, identifying query plan changes in the new version.
* Introduced improved upgrade testing using production-like workloads.
* Documented lessons learned and updated upgrade procedures.

**Result**

* Future upgrades executed smoothly.
* Reduced upgrade risk across the estate.

---

# 1️⃣2️⃣ Behaviour: Strategic Thinking

This one separates **architects from engineers**.

**Likely question**

> “Describe a time you introduced a longer-term technical strategy.”

### Example structure

**Situation**
The organisation had a fragmented database estate with inconsistent tooling and operational practices.

**Task**
Create a strategy to improve standardisation and sustainability.

**Action**

* Assessed the existing platform landscape.
* Defined architectural principles for database platforms.
* Proposed standard tooling for deployment, monitoring, and backup.
* Developed a roadmap to gradually align systems to the new standards.

**Result**

* Improved consistency across environments.
* Reduced operational complexity.
* Clear long-term platform direction.

---

# ⚠️ One Trick Interviewers Use

They sometimes ask **two behaviours in one question**, for example:

> “Tell us about a time you handled a difficult stakeholder while managing technical risk.”

Prepare stories that demonstrate **multiple competencies at once**.

---

# Very Likely RoS Behaviour Questions

I would bet money you will get **at least one of these**:

1️⃣ Handling technical risk
2️⃣ Leading architectural change
3️⃣ Influencing stakeholders
4️⃣ Learning from failure
5️⃣ Improving resilience

---

# One More Thing (Important)

You should prepare **6 reusable stories** you can adapt to almost any question:

1️⃣ Major migration
2️⃣ Production incident
3️⃣ Stakeholder disagreement
4️⃣ Technical debt reduction
5️⃣ Monitoring / observability improvement
6️⃣ Team leadership

From those, you can answer **almost any behavioural question**.

---

If you want, I can also give you something **extremely valuable for Thursday**:

**“The 7 questions UK government architects almost always get asked.”**

They are surprisingly predictable.
