-- ---------- DATABASE OPERATIONS ----------
show dbs
use SchoolDB
db
db.dropDatabase()

-- ---------- COLLECTION OPERATIONS ----------
show collections
db.createCollection("Students")
db.createCollection("Courses")
db.Students.drop()

-- ---------- CREATE: INSERT DOCUMENTS ----------
db.Students.insertOne({ _id: 1, name: "Alice", age: 20, scores: { math: 85, science: 90 } })

db.Students.insertMany([
   { _id: 1, name: "Alice",   age: 20, scores: { math: 85, science: 90 } },
   { _id: 2, name: "Bob",     age: 22, scores: { math: 78, science: 82 } },
   { _id: 3, name: "Charlie", age: 21, scores: { math: 92, science: 88 } },
   { _id: 4, name: "Daisy",   age: 23, scores: { math: 68, science: 74 } }
])

db.Courses.insertMany([
   { _id: 101, courseName: "Mathematics", instructor: "Dr. Smith", studentsEnrolled: [1, 2, 3] },
   { _id: 102, courseName: "Science",     instructor: "Dr. Adams", studentsEnrolled: [2, 3, 4] }
])

-- ---------- READ: FIND DOCUMENTS ----------
db.Students.find()
db.Students.find({ name: "Alice" })
db.Students.findOne({ name: "Alice" })

-- ---------- COMPARISON OPERATORS ----------
db.Students.find({ age: { $gt: 20 } })
db.Students.find({ age: { $gte: 20 } })
db.Students.find({ age: { $lt: 22 } })
db.Students.find({ age: { $lte: 22 } })
db.Students.find({ age: { $ne: 20 } })
db.Students.find({ "scores.math": { $gte: 80 } })

-- ---------- LOGICAL OPERATORS: AND / OR ----------
db.Students.find({
   $and: [
      { "scores.math": { $gte: 80 } },
      { "scores.science": { $lt: 90 } }
   ]
})

db.Students.find({ "scores.math": { $gte: 80 }, "scores.science": { $lt: 90 } })

db.Students.find({
   $or: [
      { age: { $lt: 23 } },
      { "scores.math": { $gte: 85 } }
   ]
})

db.Students.find({
   $and: [
      { "scores.science": { $gte: 80 } },
      { $or: [
            { "scores.math": { $lt: 75 } },
            { age: { $gt: 22 } }
        ]
      }
   ]
})

-- ---------- ARRAY QUERIES ----------
db.Courses.find({ studentsEnrolled: 3 })
db.Courses.findOne({ studentsEnrolled: 3, instructor: "Dr. Adams" })

-- ---------- UPDATE DOCUMENTS ----------
db.Students.updateOne(
   { name: "Bob" },
   { $set: { age: 25 } }
)

db.Students.updateMany(
   {},
   { $set: { status: "active" } }
)

db.Students.updateOne(
   { name: "Bob", "scores.math": { $gte: 75 } },
   { $inc: { "scores.science": 5 } }
)

db.Students.updateMany(
   { "scores.science": { $lt: 80 }, age: { $gt: 22 } },
   { $inc: { "scores.math": 5 } }
)

-- ---------- DELETE DOCUMENTS ----------
db.Students.deleteOne({ name: "Daisy", "scores.science": { $lt: 80 } })

db.Courses.deleteMany({
   $or: [
      { studentsEnrolled: 2 },
      { instructor: "Dr. Smith" }
   ]
})

-- ---------- COUNT DOCUMENTS ----------
db.books.countDocuments()
db.books.countDocuments({ publication_year: { $gt: 2000 } })

-- ---------- SORT, LIMIT, SKIP ----------
db.books.find().sort({ publication_year: 1 })
db.books.find().sort({ publication_year: -1, title: 1 })
db.books.find().limit(5)
db.books.find().skip(3)
db.books.find().skip(5).limit(5)

-- ---------- PROJECTION ----------
db.books.find({}, { title: 1, author: 1, _id: 0 })
db.books.find({}, { ISBN: 0 })

-- ---------- AGGREGATION PIPELINE ----------
db.books.aggregate([
   { $group: { _id: null, avgPublicationYear: { $avg: "$publication_year" } } }
])

db.books.aggregate([
   { $group: { _id: "$genre", count: { $sum: 1 } } }
])

db.books.aggregate([
   { $group: { _id: "$genre", count: { $sum: 1 } } },
   { $sort: { count: -1 } }
])

-- ---------- TEXT SEARCH ----------
db.books.createIndex({ title: "text", author: "text" })
db.books.find({ $text: { $search: "Road" } })

-- ---------- REGULAR EXPRESSIONS ----------
db.books.find({ title: { $regex: "^The", $options: "i" } })
db.books.find({ author: { $regex: "Lee$", $options: "i" } })

-- ---------- INCREMENT / DECREMENT ----------
db.books.updateMany({}, { $inc: { rating: 1 } })
db.books.updateOne({ title: "1984" }, { $inc: { publication_year: -5 } })

-- ---------- findOneAndUpdate / findOneAndDelete ----------
db.books.findOneAndUpdate(
   { title: "The Great Gatsby" },
   { $set: { genre: "Classic" } },
   { returnNewDocument: true }
)

db.books.findOneAndDelete({ title: "The Catcher in the Rye" })

-- ---------- DROP COLLECTION & DATABASE ----------
db.Students.drop()
db.Courses.drop()
db.dropDatabase()

-- ---------- 1. COMMIT ----------
UPDATE employees
SET salary = salary + 1000
WHERE emp_id = 101;

COMMIT;

-- ---------- 2. ROLLBACK ----------
DELETE FROM employees
WHERE emp_id = 105;

ROLLBACK;

-- ---------- 3. SAVEPOINT ----------
INSERT INTO employees VALUES (201, 'Ali', 30000);
SAVEPOINT sp1;

UPDATE employees
SET salary = 35000
WHERE emp_id = 201;

ROLLBACK TO sp1;
COMMIT;

-- ---------- 4. SET TRANSACTION ----------
SET TRANSACTION READ ONLY;

SELECT * FROM employees;

COMMIT;

-- ---------- 5. AUTOCOMMIT ----------
SET AUTOCOMMIT ON;

INSERT INTO employees VALUES (202, 'Sara', 40000);

SET AUTOCOMMIT OFF;
