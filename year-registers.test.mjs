import test from 'node:test';
import assert from 'node:assert/strict';
import { studentYear, studentsForYear, availableYears, financeTotals } from '../year-utils.mjs';

const fixture = () => ({
    legacy: { name: 'Existing student', records: { January: { paid: '500', due: '100', studentSign: 'saved-signature' } }, teacherFiles: [{ url: 'saved-file' }] },
    next: { name: 'New student', academicYear: 2027, records: { January: { paid: '900', due: '50' } } }
});

test('legacy records remain in 2026 after the calendar year changes', () => {
    const students = fixture();
    assert.equal(studentYear(students.legacy), 2026);
    assert.deepEqual(Object.keys(studentsForYear(students, 2026)), ['legacy']);
    assert.deepEqual(Object.keys(studentsForYear(students, 2027)), ['next']);
    assert.deepEqual(availableYears(students, 2028), [2026, 2027, 2028, 2029]);
});

test('monthly and yearly totals never mix cohorts', () => {
    const students = fixture();
    assert.deepEqual(financeTotals(students, 2026, ['January', 'February']), { paid: 500, due: 100 });
    assert.deepEqual(financeTotals(students, 2027, ['January', 'February']), { paid: 900, due: 50 });
    assert.deepEqual(financeTotals(students, 2028, ['January']), { paid: 0, due: 0 });
});

test('reading registers does not mutate payments, signatures, or previous files', () => {
    const students = fixture();
    const before = structuredClone(students);
    studentsForYear(students, 2027);
    availableYears(students, 2028, [2030]);
    financeTotals(students, 2026, ['January']);
    assert.deepEqual(students, before);
});

test('invalid year metadata falls back safely and invalid folder values are excluded', () => {
    assert.equal(studentYear({ academicYear: 'broken' }), 2026);
    assert.equal(studentYear({ academicYear: null }), 2026);
    assert.equal(studentYear({ academicYear: '2027' }), 2027);
    assert.deepEqual(availableYears({}, 2026, ['bad', 2027, 2030, 2030, 99999]), [2026, 2027, 2030]);
});
