INSERT INTO `jobs` (name, label) VALUES
	('shop', 'Shop');

INSERT INTO `job_grades` (job_name, grade, name, label, salary, skin_male, skin_female) VALUES
	('shop',0,'apprentice','Apprentice',200,'{}','{}'),
	('shop',1,'clerk','Clerk',300,'{}','{}'),
	('shop',2,'boss','Owner',400,'{}','{}');

CREATE TABLE `t1ger_shops` (
	`identifier` varchar(100) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL,
	`shopID` INT(11),
	`money` INT(11) NOT NULL DEFAULT 0,
	`employees` longtext NOT NULL DEFAULT '[]',
	`stock` longtext NOT NULL DEFAULT '[]',
	`shelves` longtext NOT NULL DEFAULT '[]',
	PRIMARY KEY (`shopID`)
);

INSERT INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
('water', 'Water', 10, 0, 1),
('redgull', 'Energy Drink', 10, 0, 1),
('pisswasser', 'Pisswasser', 10, 0, 1),
('sandwich', 'Sandwich', 10, 0, 1),
('bread', 'Bread', 10, 0, 1),
('donut', 'Donut', 10, 0, 1),
('tacos', 'Tacos', 10, 0, 1),
('umbrella', 'Umbrella', 10, 0, 1),
('lockpick', 'Lockpick', 10, 0, 1),
('binoculars', 'Binoculars', 10, 0, 1),
('oxygenmask', 'Oxygen Mask', 10, 0, 1),
('repairkit', 'Repair Kit', 10, 0, 1);
