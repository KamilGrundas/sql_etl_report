-- Wyniki przedstawione na jednym zrzucie ekranu w poprawnej kolejności

-- 1)
SELECT
  COUNT(*) AS UniqueCustomers
FROM
  dbo.DimCustomer;

-- 2)
SELECT
  c.CustomerKey,
  c.FirstName,
  c.LastName,
  g.EnglishCountryRegionName
FROM
  dbo.DimCustomer c
  INNER JOIN dbo.DimGeography g ON g.GeographyKey = c.GeographyKey -- dodaje kolumnę z pelną nazwą kraju
WHERE
  UPPER(g.EnglishCountryRegionName) = 'GERMANY'
  AND c.FirstName LIKE '%a%';

-- 3)
SELECT
  g.EnglishCountryRegionName AS Country,
  COUNT(*) AS CustomerCount
FROM
  dbo.DimCustomer c
  INNER JOIN dbo.DimGeography g ON g.GeographyKey = c.GeographyKey
GROUP BY
  g.EnglishCountryRegionName
ORDER BY
  CustomerCount DESC;

-- 4)
SELECT
  p.ProductKey,
  p.EnglishProductName
FROM
  dbo.DimProduct AS p
WHERE
  p.FinishedGoodsFlag = 1 -- sprawdzenie czy produkt jest przedmiotem "gotowym do sprzedazy"
  AND NOT EXISTS ( -- proste sprawdzenie
    SELECT
      1
    FROM
      dbo.FactInternetSales
    WHERE
      ProductKey = p.ProductKey
  )
  AND NOT EXISTS (
    SELECT
      1
    FROM
      dbo.FactResellerSales
    WHERE
      ProductKey = p.ProductKey
  )
ORDER BY
  p.EnglishProductName;


-- 5)
WITH
  Spend2013 AS ( -- użycie CTE dla pobrania sumy wszystkich zamówień clientów
    SELECT
      c.CustomerKey,
      c.FirstName,
      c.LastName,
      c.EmailAddress,
      SUM(s.SalesAmount) AS TotalSpent
    FROM
      dbo.FactInternetSales AS s -- bierzemy pod uwagę tylko InternetSales, bo tylko tam są zapisywani klienci
      JOIN dbo.DimCustomer AS c ON c.CustomerKey = s.CustomerKey
      JOIN dbo.DimDate AS d ON d.DateKey = s.OrderDateKey
    WHERE
      d.CalendarYear = 2013
    GROUP BY
      c.CustomerKey,
      c.FirstName,
      c.LastName,
      c.EmailAddress
  )
SELECT
  TOP (1)
WITH
  TIES -- Top 1 uwzględniając remisy
  CustomerKey,
  FirstName,
  LastName,
  EmailAddress,
  TotalSpent
FROM
  Spend2013
ORDER BY
  TotalSpent DESC;


-- 6) Zapytanie nic nie zwraca, natomiast poprawki wprowadzone znacznie poprawiają czytelność dzięki zastosowaniu CTE
-- dodatkowo użycie filtrów wcześniej - powoduje uniknięcie zagnieżdżonych zapytań IN (SELECT ... ) co jest wydajniejsze
-- w celu jeszcze lepszych efektów wydajnościowych można zastosować indexy
WITH
  Products AS ( -- utworzenie CTE dla lepszej czytelności
    SELECT
      p.ProductKey
    FROM
      dbo.DimProduct AS p
    WHERE
      p.EnglishProductName LIKE '%Mountain%'
      AND p.Color IN ('Red', 'Silver', 'Black')
  ),
  Dates AS ( -- CTE dla lepszej czytelności
    SELECT
      d.DateKey
    FROM
      dbo.DimDate AS d
    WHERE
      d.CalendarYear BETWEEN 2012 AND 2014
      AND d.DayNumberOfWeek IN (1, 7)
  ),
  OrderAgg AS (
    SELECT
      s.SalesOrderNumber,
      s.CustomerKey,
      SUM(s.SalesAmount) AS OrderAmount
    FROM
      dbo.FactInternetSales AS s
      JOIN Products AS p ON p.ProductKey = s.ProductKey
      JOIN Dates AS d ON d.DateKey = s.OrderDateKey
    GROUP BY
      s.SalesOrderNumber,
      s.CustomerKey
  ) -- zastosowanie CTE pozwala na użycie filtrów wcześniej, dzięki czemu nie używamy IN (SELECT .... 
SELECT
  c.CustomerKey,
  c.FirstName,
  c.LastName,
  COUNT(*) AS OrderCount,
  SUM(OrderAmount) AS TotalSpent
FROM
  OrderAgg AS oa
  JOIN dbo.DimCustomer AS c ON c.CustomerKey = oa.CustomerKey
GROUP BY
  c.CustomerKey,
  c.FirstName,
  c.LastName
HAVING
  SUM(OrderAmount) > 5000
ORDER BY
  TotalSpent DESC;
