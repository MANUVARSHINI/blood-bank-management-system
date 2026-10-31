// =====================================================================
// BLOOD BANK MANAGEMENT SYSTEM - DA 3 (Neo4j Graph Database)
// Run each statement in Neo4j Browser / Aura Query / Sandbox, IN ORDER.
// Statements are separated by semicolons. Run them one section at a time.
// =====================================================================

// ---------------------------------------------------------------------
// SECTION 0 (optional): CLEAN SLATE - wipes everything, use to re-run
// ---------------------------------------------------------------------
MATCH (n) DETACH DELETE n;

// ---------------------------------------------------------------------
// SECTION 1: CONSTRAINTS (graph equivalent of PRIMARY KEY)
// ---------------------------------------------------------------------
CREATE CONSTRAINT donor_id IF NOT EXISTS FOR (n:Donor) REQUIRE n.donor_id IS UNIQUE;
CREATE CONSTRAINT donation_id IF NOT EXISTS FOR (n:Donation) REQUIRE n.donation_id IS UNIQUE;
CREATE CONSTRAINT unit_id IF NOT EXISTS FOR (n:BloodUnit) REQUIRE n.unit_id IS UNIQUE;
CREATE CONSTRAINT hospital_id IF NOT EXISTS FOR (n:Hospital) REQUIRE n.hospital_id IS UNIQUE;
CREATE CONSTRAINT patient_id IF NOT EXISTS FOR (n:Patient) REQUIRE n.patient_id IS UNIQUE;
CREATE CONSTRAINT request_id IF NOT EXISTS FOR (n:Request) REQUIRE n.request_id IS UNIQUE;
CREATE CONSTRAINT issue_id IF NOT EXISTS FOR (n:Issue) REQUIRE n.issue_id IS UNIQUE;
CREATE CONSTRAINT bg_name IF NOT EXISTS FOR (n:BloodGroup) REQUIRE n.name IS UNIQUE;

// ---------------------------------------------------------------------
// SECTION 2: SAMPLE DATA
// ---------------------------------------------------------------------

// 2.1 Blood groups (new node type: replaces the repeated Blood_Group text columns)
UNWIND ['O+','O-','A+','A-','B+','B-','AB+','AB-'] AS bg
MERGE (:BloodGroup {name: bg});

// 2.2 Red-cell compatibility (who can donate to whom) - stored as relationships
UNWIND [
  ['O-',  ['O-','O+','A-','A+','B-','B+','AB-','AB+']],
  ['O+',  ['O+','A+','B+','AB+']],
  ['A-',  ['A-','A+','AB-','AB+']],
  ['A+',  ['A+','AB+']],
  ['B-',  ['B-','B+','AB-','AB+']],
  ['B+',  ['B+','AB+']],
  ['AB-', ['AB-','AB+']],
  ['AB+', ['AB+']]
] AS row
MATCH (a:BloodGroup {name: row[0]})
UNWIND row[1] AS target
MATCH (b:BloodGroup {name: target})
MERGE (a)-[:CAN_DONATE_TO]->(b);

// 2.3 Donors (first three are the DA 2 donors)
UNWIND [
  {id:1, name:'Arun Kumar',   gender:'Male',   age:28, bg:'O+',  phone:'9876543210', city:'Chennai'},
  {id:2, name:'Priya S',      gender:'Female', age:24, bg:'A+',  phone:'9876500000', city:'Chennai'},
  {id:3, name:'Ravi Shankar', gender:'Male',   age:31, bg:'B+',  phone:'9988776655', city:'Coimbatore'},
  {id:4, name:'Meena K',      gender:'Female', age:27, bg:'O-',  phone:'9845012345', city:'Chennai'},
  {id:5, name:'Suresh V',     gender:'Male',   age:35, bg:'A-',  phone:'9790011223', city:'Madurai'},
  {id:6, name:'Lakshmi P',    gender:'Female', age:30, bg:'O+',  phone:'9884455667', city:'Chennai'}
] AS r
MERGE (d:Donor {donor_id: r.id})
SET d.name = r.name, d.gender = r.gender, d.age = r.age,
    d.phone = r.phone, d.city = r.city
WITH d, r
MATCH (bg:BloodGroup {name: r.bg})
MERGE (d)-[:HAS_TYPE]->(bg);

// 2.4 Donations (dates are relative to today so expiry logic always works)
UNWIND [
  {id:101, donor:1, ago:5,   qty:350},
  {id:102, donor:2, ago:4,   qty:350},
  {id:103, donor:3, ago:3,   qty:350},
  {id:104, donor:4, ago:55,  qty:350},
  {id:105, donor:5, ago:6,   qty:350},
  {id:106, donor:6, ago:120, qty:350}
] AS r
MATCH (d:Donor {donor_id: r.donor})
MERGE (dn:Donation {donation_id: r.id})
SET dn.donation_date = date() - duration({days: r.ago}), dn.quantity = r.qty
MERGE (d)-[:MADE]->(dn);

// 2.5 Blood units (shelf life 42 days as in DA 2). Unit 204 is deliberately EXPIRED for demo.
UNWIND [
  {id:201, donation:101, bg:'O+', ago:5},
  {id:202, donation:102, bg:'A+', ago:4},
  {id:203, donation:103, bg:'B+', ago:3},
  {id:204, donation:104, bg:'O-', ago:55},
  {id:205, donation:105, bg:'A-', ago:6}
] AS r
MATCH (dn:Donation {donation_id: r.donation})
MATCH (bg:BloodGroup {name: r.bg})
MERGE (u:BloodUnit {unit_id: r.id})
SET u.quantity = 350,
    u.collection_date = date() - duration({days: r.ago}),
    u.expiry_date     = date() - duration({days: r.ago}) + duration({days: 42})
MERGE (dn)-[:PRODUCED]->(u)
MERGE (u)-[:HAS_TYPE]->(bg);

// 2.6 Keep Donor.last_donation_date in sync with their latest donation
MATCH (d:Donor)-[:MADE]->(dn:Donation)
WITH d, max(dn.donation_date) AS last
SET d.last_donation_date = last;

// 2.7 Hospitals
UNWIND [
  {id:301, name:'City General Hospital', address:'Anna Nagar, Chennai',  phone:'04423456789'},
  {id:302, name:'Apollo Hospital',       address:'Greams Road, Chennai', phone:'04428290200'}
] AS r
MERGE (h:Hospital {hospital_id: r.id})
SET h.name = r.name, h.address = r.address, h.contact = r.phone;

// 2.8 Patients
UNWIND [
  {id:401, name:'Karthik R', gender:'Male',   age:35, bg:'O+',  phone:'9123456789', address:'Velachery, Chennai'},
  {id:402, name:'Deepa N',   gender:'Female', age:29, bg:'A+',  phone:'9012345678', address:'Adyar, Chennai'},
  {id:403, name:'Anitha M',  gender:'Female', age:41, bg:'AB+', phone:'9001122334', address:'T Nagar, Chennai'}
] AS r
MERGE (p:Patient {patient_id: r.id})
SET p.name = r.name, p.gender = r.gender, p.age = r.age,
    p.phone = r.phone, p.address = r.address
WITH p, r
MATCH (bg:BloodGroup {name: r.bg})
MERGE (p)-[:HAS_TYPE]->(bg);

// 2.9 Blood requests
UNWIND [
  {id:501, patient:401, hospital:301, bg:'O+',  qty:2, status:'Pending'},
  {id:502, patient:402, hospital:302, bg:'A+',  qty:1, status:'Pending'},
  {id:503, patient:403, hospital:301, bg:'AB+', qty:1, status:'Pending'}
] AS r
MATCH (p:Patient  {patient_id:  r.patient})
MATCH (h:Hospital {hospital_id: r.hospital})
MATCH (bg:BloodGroup {name: r.bg})
MERGE (rq:Request {request_id: r.id})
SET rq.quantity = r.qty, rq.status = r.status
MERGE (p)-[:RAISED]->(rq)
MERGE (rq)-[:AT_HOSPITAL]->(h)
MERGE (rq)-[:NEEDS]->(bg);

// ---------------------------------------------------------------------
// SECTION 3: CORE OPERATIONS (CRUD) - same as DA 2 sample queries
// ---------------------------------------------------------------------

// 3.1 READ: list all donors with blood group
MATCH (d:Donor)-[:HAS_TYPE]->(bg:BloodGroup)
RETURN d.donor_id AS id, d.name AS donor, bg.name AS blood_group, d.city AS city
ORDER BY id;

// 3.2 READ: donors who donated in the last 90 days (DA 2 query 1)
MATCH (d:Donor)
WHERE d.last_donation_date >= date() - duration({days: 90})
RETURN d.name AS donor, d.last_donation_date AS last_donation;

// 3.3 READ: pending requests with patient and hospital (DA 2 query 3, no JOINs needed)
MATCH (p:Patient)-[:RAISED]->(r:Request)-[:AT_HOSPITAL]->(h:Hospital),
      (r)-[:NEEDS]->(bg:BloodGroup)
RETURN r.request_id AS request, p.name AS patient, h.name AS hospital,
       bg.name AS blood_group, r.status AS status;

// 3.4 CREATE: register a new donor
MATCH (bg:BloodGroup {name:'B-'})
CREATE (d:Donor {donor_id:7, name:'Vikram T', gender:'Male', age:33,
                 phone:'9700011122', city:'Chennai'})
CREATE (d)-[:HAS_TYPE]->(bg)
RETURN d;

// 3.5 UPDATE: change a donor's phone number
MATCH (d:Donor {donor_id:7})
SET d.phone = '9700099999'
RETURN d.name, d.phone;

// 3.6 DELETE: remove that donor again
MATCH (d:Donor {donor_id:7})
DETACH DELETE d;

// ---------------------------------------------------------------------
// SECTION 4: TECHNOLOGY-SPECIFIC (GRAPH) QUERIES
// ---------------------------------------------------------------------

// 4.1 AVAILABLE STOCK: unissued, non-expired units per blood group (DA 2 query 2)
MATCH (u:BloodUnit)-[:HAS_TYPE]->(bg:BloodGroup)
WHERE u.expiry_date > date()
  AND NOT EXISTS { (u)<-[:USED_UNIT]-(:Issue) }
RETURN bg.name AS blood_group, count(u) AS units_available
ORDER BY blood_group;

// 4.2 EXPIRED OR NEAR-EXPIRY units (days remaining; negative = already expired)
MATCH (u:BloodUnit)-[:HAS_TYPE]->(bg:BloodGroup)
WHERE NOT EXISTS { (u)<-[:USED_UNIT]-(:Issue) }
WITH u, bg, duration.inDays(date(), u.expiry_date).days AS days_left
WHERE days_left <= 14
RETURN u.unit_id AS unit, bg.name AS blood_group, u.expiry_date AS expiry, days_left
ORDER BY days_left;

// 4.3 COMPATIBLE DONORS for a patient (this is the one SQL does badly).
//     Patient 403 is AB+ (universal recipient) so every donor matches.
MATCH (p:Patient {patient_id:403})-[:HAS_TYPE]->(need:BloodGroup)
MATCH (d:Donor)-[:HAS_TYPE]->(dg:BloodGroup)-[:CAN_DONATE_TO]->(need)
RETURN d.name AS donor, dg.name AS donor_group, d.city AS city
ORDER BY donor_group;

// 4.4 ELIGIBLE DONORS: last donation more than 90 days ago, compatible with patient 401 (O+)
MATCH (p:Patient {patient_id:401})-[:HAS_TYPE]->(need:BloodGroup)
MATCH (d:Donor)-[:HAS_TYPE]->(dg:BloodGroup)-[:CAN_DONATE_TO]->(need)
WHERE d.last_donation_date + duration({days: 90}) <= date()
RETURN d.name AS donor, dg.name AS group, d.city AS city, d.phone AS phone;

// 4.5 FULFIL A REQUEST (replaces PL/SQL procedure fulfill_request).
//     Picks the best unit: exact group first, then compatible group, oldest expiry first.
//     Skips expired and already-issued units. Run for 501, then change the id to 502.
MATCH (x:Issue)
WITH coalesce(max(x.issue_id), 0) + 1 AS new_id
MATCH (r:Request {request_id: 501, status: 'Pending'})-[:NEEDS]->(need:BloodGroup)
MATCH (u:BloodUnit)-[:HAS_TYPE]->(dg:BloodGroup)-[:CAN_DONATE_TO]->(need)
WHERE u.expiry_date > date()
  AND NOT EXISTS { (u)<-[:USED_UNIT]-(:Issue) }
WITH new_id, r, u, dg, need
ORDER BY (dg = need) DESC, u.expiry_date ASC
LIMIT 1
CREATE (i:Issue {issue_id: new_id, issue_date: date(), quantity: r.quantity})
CREATE (i)-[:FULFILLS]->(r)
CREATE (i)-[:USED_UNIT]->(u)
SET r.status = 'Fulfilled'
RETURN r.request_id AS request, u.unit_id AS unit_issued, dg.name AS unit_group;

MATCH (x:Issue)
WITH coalesce(max(x.issue_id), 0) + 1 AS new_id
MATCH (r:Request {request_id: 502, status: 'Pending'})-[:NEEDS]->(need:BloodGroup)
MATCH (u:BloodUnit)-[:HAS_TYPE]->(dg:BloodGroup)-[:CAN_DONATE_TO]->(need)
WHERE u.expiry_date > date()
  AND NOT EXISTS { (u)<-[:USED_UNIT]-(:Issue) }
WITH new_id, r, u, dg, need
ORDER BY (dg = need) DESC, u.expiry_date ASC
LIMIT 1
CREATE (i:Issue {issue_id: new_id, issue_date: date(), quantity: r.quantity})
CREATE (i)-[:FULFILLS]->(r)
CREATE (i)-[:USED_UNIT]->(u)
SET r.status = 'Fulfilled'
RETURN r.request_id AS request, u.unit_id AS unit_issued, dg.name AS unit_group;

// 4.6 TRACEABILITY: follow every issued unit from donor to patient in one pattern
MATCH path = (d:Donor)-[:MADE]->(:Donation)-[:PRODUCED]->(u:BloodUnit)
             <-[:USED_UNIT]-(:Issue)-[:FULFILLS]->(r:Request)
             <-[:RAISED]-(p:Patient)
MATCH (r)-[:AT_HOSPITAL]->(h:Hospital)
RETURN d.name AS donor, u.unit_id AS unit, p.name AS patient, h.name AS hospital;

// 4.7 RECALL: if donor 1 is found unsafe, which patients and hospitals are affected?
MATCH (d:Donor {donor_id:1})-[:MADE]->(:Donation)-[:PRODUCED]->(u:BloodUnit)
      <-[:USED_UNIT]-(:Issue)-[:FULFILLS]->(r:Request)<-[:RAISED]-(p:Patient),
      (r)-[:AT_HOSPITAL]->(h:Hospital)
RETURN d.name AS donor, u.unit_id AS unit, p.name AS affected_patient,
       p.phone AS patient_phone, h.name AS hospital;

// 4.8 PENDING REQUESTS and how many valid units could serve each one
MATCH (r:Request {status:'Pending'})-[:NEEDS]->(need:BloodGroup),
      (r)<-[:RAISED]-(p:Patient)
OPTIONAL MATCH (u:BloodUnit)-[:HAS_TYPE]->(:BloodGroup)-[:CAN_DONATE_TO]->(need)
WHERE u.expiry_date > date() AND NOT EXISTS { (u)<-[:USED_UNIT]-(:Issue) }
RETURN r.request_id AS request, p.name AS patient, need.name AS needs,
       count(u) AS compatible_units_in_stock;

// 4.9 HOSPITAL DEMAND: requests per hospital
MATCH (h:Hospital)<-[:AT_HOSPITAL]-(r:Request)
RETURN h.name AS hospital, count(r) AS total_requests,
       sum(CASE WHEN r.status = 'Pending' THEN 1 ELSE 0 END) AS pending
ORDER BY total_requests DESC;

// 4.10 VISUALISE the whole graph (switch to Graph view in Neo4j Browser; good for demo)
MATCH p = (n)-[r]->(m)
WHERE NOT n:BloodGroup OR NOT m:BloodGroup
RETURN p LIMIT 100;

// 4.11 SCHEMA view (shows the graph model itself)
CALL db.schema.visualization();
