// MongoDB document model: loan applications for InterestFree Lend
// Run:  docker compose exec -T mongo mongosh ifl < mongo_loan_applications.js
// Why a document? Each application is read as ONE unit together with its KYC data, supporting
// documents, guarantors and status history, whose shape varies by product. In SQL this needs
// 5+ joins and nullable columns; here it is one embedded document.

db = db.getSiblingDB('ifl');
db.loan_applications.drop();

db.loan_applications.insertMany([
  {
    _id: 'APP-1001',
    customer: { id: 1, name: 'Tunde Adeyemi', phone: '08030000001', region: 'West' },
    product: 'Micro Trader Loan',
    requestedAmount: 100000, tenorMonths: 6, status: 'APPROVED',
    kyc: { nationalId: 'NIN0000001', verified: true, documents: [
        { type: 'ID_CARD', file: 'tunde_id.jpg' }, { type: 'UTILITY_BILL', file: 'tunde_bill.pdf' } ] },
    business: { type: 'Provision store', monthlyRevenue: 250000, location: 'Ibadan' },   // varies by product
    guarantors: [ { customerId: 2, name: 'Fatima Yusuf' }, { customerId: 3, name: 'Emeka Okafor' } ],
    statusHistory: [
      { status: 'PENDING',  at: ISODate('2026-11-01T09:00:00Z') },
      { status: 'APPROVED', at: ISODate('2026-11-02T14:30:00Z'), by: 'Amina Bello' } ],
    tags: ['trader', 'repeat-customer']
  },
  {
    _id: 'APP-1002',
    customer: { id: 2, name: 'Fatima Yusuf', phone: '08030000002', region: 'North' },
    product: 'Micro Trader Loan',
    requestedAmount: 50000, tenorMonths: 5, status: 'APPROVED',
    kyc: { nationalId: 'NIN0000002', verified: true, documents: [ { type: 'ID_CARD', file: 'fatima_id.jpg' } ] },
    business: { type: 'Tailoring', monthlyRevenue: 90000, location: 'Kano' },
    guarantors: [ { customerId: 1, name: 'Tunde Adeyemi' } ],
    statusHistory: [ { status: 'PENDING', at: ISODate('2026-11-01T10:00:00Z') },
                     { status: 'APPROVED', at: ISODate('2026-11-02T14:35:00Z'), by: 'Amina Bello' } ],
    tags: ['artisan']
  },
  {
    _id: 'APP-1003',
    customer: { id: 3, name: 'Emeka Okafor', phone: '08030000003', region: 'East' },
    product: 'Education Support',
    requestedAmount: 200000, tenorMonths: 10, status: 'PENDING',
    kyc: { nationalId: 'NIN0000003', verified: true, documents: [] },
    education: { institution: 'University of Nigeria', admissionLetter: 'emeka_admission.pdf', feesDue: 200000 },  // different shape
    guarantors: [ { customerId: 4, name: 'Blessing Udo' } ],
    statusHistory: [ { status: 'PENDING', at: ISODate('2026-11-09T08:00:00Z') } ],
    tags: ['student']
  },
  {
    _id: 'APP-1004',
    customer: { id: 4, name: 'Blessing Udo', phone: '08030000004', region: 'South' },
    product: 'Emergency Relief',
    requestedAmount: 40000, tenorMonths: 3, status: 'REJECTED',
    kyc: { nationalId: 'NIN0000004', verified: true, documents: [] },
    rejectionReason: 'Incomplete documents',
    guarantors: [],
    statusHistory: [ { status: 'PENDING', at: ISODate('2026-11-05T08:00:00Z') },
                     { status: 'REJECTED', at: ISODate('2026-11-06T08:00:00Z'), by: 'Amina Bello' } ],
    tags: ['medical']
  }
]);

print('--- Q1: retrieve one full application (single read, no joins) ---');
printjson(db.loan_applications.findOne({ _id: 'APP-1001' }));

print('--- Q2: approved applications in West or North above 40k ---');
printjson(db.loan_applications.find(
  { status: 'APPROVED', 'customer.region': { $in: ['West', 'North'] }, requestedAmount: { $gt: 40000 } },
  { 'customer.name': 1, requestedAmount: 1, product: 1 }).toArray());

print('--- Q3: applications guaranteed by customer 1 (query inside an embedded array) ---');
printjson(db.loan_applications.find({ 'guarantors.customerId': 1 }, { _id: 1, 'customer.name': 1 }).toArray());

print('--- Q4: schema flexibility: only education loans have an "education" sub-document ---');
printjson(db.loan_applications.find({ education: { $exists: true } }, { _id: 1, education: 1 }).toArray());

print('--- Q5: aggregation: total requested per product and status ---');
printjson(db.loan_applications.aggregate([
  { $group: { _id: { product: '$product', status: '$status' }, total: { $sum: '$requestedAmount' }, count: { $sum: 1 } } },
  { $sort: { total: -1 } }
]).toArray());

print('--- Q6: update: append status history and change status atomically (single-document atomicity) ---');
db.loan_applications.updateOne({ _id: 'APP-1003' }, {
  $set: { status: 'APPROVED' },
  $push: { statusHistory: { status: 'APPROVED', at: new Date(), by: 'Amina Bello' } }
});
printjson(db.loan_applications.findOne({ _id: 'APP-1003' }, { status: 1, statusHistory: 1 }));

print('--- Indexing + explain ---');
db.loan_applications.createIndex({ status: 1, 'customer.region': 1 });
db.loan_applications.createIndex({ 'guarantors.customerId': 1 });          // multikey index
const plan = db.loan_applications.find({ status: 'APPROVED', 'customer.region': 'West' }).explain('executionStats');
printjson({ stage: plan.queryPlanner.winningPlan.stage || plan.queryPlanner.winningPlan.inputStage,
            docsExamined: plan.executionStats.totalDocsExamined, returned: plan.executionStats.nReturned });
