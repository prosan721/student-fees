// Existing, untagged records belong to the original 2026 register.
// Reading a year never changes or migrates stored student data.
export const LEGACY_YEAR = 2026;

export function studentYear(student) {
    const year = Number(student.academicYear);
    return Number.isInteger(year) && year >= 2000 && year <= 2100 ? year : LEGACY_YEAR;
}

export function studentsForYear(students, year) {
    return Object.fromEntries(Object.entries(students).filter(([, student]) => studentYear(student) === Number(year)));
}

export function availableYears(students, currentYear, extraYears = []) {
    return [...new Set([LEGACY_YEAR, currentYear, currentYear + 1, ...extraYears,
        ...Object.values(students).map(studentYear)])]
        .filter(year => Number.isInteger(year) && year >= 2000 && year <= 2100)
        .sort((a, b) => a - b);
}

export function financeTotals(students, year, months) {
    return Object.values(studentsForYear(students, year)).reduce((total, student) => {
        for (const month of months) {
            const record = student.records?.[month];
            total.paid += Number.parseInt(record?.paid, 10) || 0;
            total.due += Number.parseInt(record?.due, 10) || 0;
        }
        return total;
    }, { paid: 0, due: 0 });
}
