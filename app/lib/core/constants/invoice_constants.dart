/// Empty (tare) weight per unit count: tare (kg) = count × [tareKgPerUnit].
const double invoiceTareKgPerUnit = 8;

double invoiceTareWeight(int count) => count * invoiceTareKgPerUnit;
