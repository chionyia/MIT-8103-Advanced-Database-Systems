// Graph model: who guarantees whom. Run in Neo4j Browser (http://localhost:7474, neo4j / ifl_pass_123)
// or: docker compose exec -T neo4j cypher-shell -u neo4j -p ifl_pass_123 < neo4j_guarantor_graph.cypher
// Why a graph? Questions such as "if this borrower defaults, who is exposed through chains of
// guarantees?" are multi-hop traversals: slow, recursive joins in SQL but a native pattern in Cypher.

MATCH (n) DETACH DELETE n;

CREATE (t:Customer {id:1, name:'Tunde Adeyemi',  region:'West'}),
       (f:Customer {id:2, name:'Fatima Yusuf',   region:'North'}),
       (e:Customer {id:3, name:'Emeka Okafor',   region:'East'}),
       (b:Customer {id:4, name:'Blessing Udo',   region:'South'}),
       (i:Customer {id:5, name:'Ibrahim Musa',   region:'North'}),
       (l1:Loan {id:'L1', amount:100000, status:'ACTIVE'}),
       (l2:Loan {id:'L2', amount:50000,  status:'DEFAULTED'}),
       (l3:Loan {id:'L3', amount:200000, status:'ACTIVE'}),
       (t)-[:BORROWED]->(l1),
       (f)-[:BORROWED]->(l2),
       (e)-[:BORROWED]->(l3),
       (f)-[:GUARANTEES]->(l1),
       (e)-[:GUARANTEES]->(l1),
       (t)-[:GUARANTEES]->(l2),
       (b)-[:GUARANTEES]->(l3),
       (i)-[:REFERRED_BY]->(t);

// Q1. Who guarantees Tunde's loan?
MATCH (g:Customer)-[:GUARANTEES]->(:Loan)<-[:BORROWED]-(:Customer {name:'Tunde Adeyemi'}) RETURN g.name;

// Q2. Risk exposure: guarantors of any DEFAULTED loan
MATCH (g:Customer)-[:GUARANTEES]->(l:Loan {status:'DEFAULTED'})
RETURN g.name AS exposed_guarantor, l.id AS defaulted_loan, l.amount;

// Q3. Two-hop chain: customers whose guarantor is themselves a borrower in default
MATCH (b:Customer)-[:BORROWED]->(:Loan)<-[:GUARANTEES]-(g:Customer)-[:BORROWED]->(dl:Loan {status:'DEFAULTED'})
RETURN b.name AS borrower_at_risk, g.name AS guarantor_in_default;

// Q4. Mutual guarantee rings (possible fraud signal)
MATCH (a:Customer)-[:GUARANTEES]->(:Loan)<-[:BORROWED]-(b:Customer),
      (b)-[:GUARANTEES]->(:Loan)<-[:BORROWED]-(a)
WHERE a.id < b.id
RETURN a.name, b.name;
