# AI Use Declaration

**1. AI tool used:** Claude Code (Anthropic, Claude Sonnet 5.5).

**2. What it was used for:**
- Explaining the assignment requirements and helping me choose the InterestFree Lend case study.
- Drafting the repository structure, SQL, MongoDB, Neo4j and Redis scripts, Docker configuration, and README templates.
- Running the scripts in Docker to check they work, including the MongoDB, Neo4j and Redis scripts, the MongoDB failover test, and the two-session concurrency tests, and generating the `test-output/` files in Portfolio 3 and the output files in Portfolio 4.
- Drafting the performance analysis, discussion sections, and reflection text from the results I produced.

**3. How I reviewed, tested and verified the output:**
- I ran the PostgreSQL work myself in my own terminal: the schema and seed (Portfolio 1), the large dataset, the before and after `EXPLAIN ANALYZE` plans, the indexes and the business queries (Portfolio 2), the commit, rollback and savepoint demo and the two-terminal lost-update setup (Portfolio 3), and the primary and replica replication setup (Portfolio 5). The screenshots in the repository are from my own terminal.
- I compared the results with what each script was meant to show, for example the constraint error and unchanged balances after the rollback, and the replica refusing writes.
- I corrected problems I hit while testing, such as running a command from the wrong folder and resetting a balance left over from an earlier run before repeating the lost-update demo.
- I read and edited the analysis and reflection so they match the numbers from my runs and my own understanding of the design.

Other sources: official PostgreSQL, MongoDB, Neo4j and Redis documentation.
