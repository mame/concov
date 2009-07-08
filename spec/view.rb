#
# concov - continuous coverage manager
#
#   * spec/view.rb: view spec
#

require "ramaze"
require "ramaze/spec/bacon"

require "lib/date"
require "lib/view"


describe Concov::View do
  day1 = Date.parse("20090101")
  day_view = Concov::DayView.new(day1)
  week_view = Concov::WeekView.new(day1)
  diff_view1 = Concov::DiffView.new(Date.parse("20081231"), day1)
  diff_view2 = Concov::DiffView.new(Date.parse("20081201"), day1)
  changes_view = Concov::ChangesView.new(day1)
  chart_view = Concov::ChartView.new(day1)

  should "parse correctly" do
    Concov::View.parse("20090101")         .should == day_view
    Concov::View.parse("w20090101")        .should == week_view
    Concov::View.parse("d20090101")        .should == diff_view1
    Concov::View.parse("20081201d20090101").should == diff_view2
    Concov::View.parse("c20090101")        .should == changes_view
    Concov::View.parse("g20090101")        .should == chart_view
    ->{ Concov::View.parse("z20090101") }.should.raise(Concov::ConcovError)
  end

  should "return current date" do
    day_view    .date.should == day1
    week_view   .date.should == day1
    diff_view1  .date.should == day1
    diff_view2  .date.should == day1
    changes_view.date.should == day1
    chart_view  .date.should == day1
  end

  should "enumerate dates in view" do
    day_view    .to_a.should == [day1]
    week_view   .to_a.should == (Date.parse("20081226")..day1).to_a
    diff_view1  .to_a.should == [Date.parse("20081231"), day1]
    diff_view2  .to_a.should == [Date.parse("20081201"), day1]
    ->{ changes_view.to_a }.should.raise(Concov::ConcovError)
    ->{ chart_view  .to_a }.should.raise(Concov::ConcovError)
  end

  should "convert correctly" do
    day_view    .to_day_view.should == day_view
    week_view   .to_day_view.should == day_view
    diff_view1  .to_day_view.should == day_view
    diff_view2  .to_day_view.should == day_view
    changes_view.to_day_view.should == day_view
    chart_view  .to_day_view.should == day_view

    day_view    .to_week_view.should == week_view
    week_view   .to_week_view.should == week_view
    diff_view1  .to_week_view.should == week_view
    diff_view2  .to_week_view.should == week_view
    changes_view.to_week_view.should == week_view
    chart_view  .to_week_view.should == week_view

    day_view    .to_diff_view.should == diff_view1
    week_view   .to_diff_view.should == diff_view1
    diff_view1  .to_diff_view.should == diff_view1
    diff_view2  .to_diff_view.should == diff_view1
    changes_view.to_diff_view.should == diff_view1
    chart_view  .to_diff_view.should == diff_view1

    day_view    .to_changes_view.should == changes_view
    week_view   .to_changes_view.should == changes_view
    diff_view1  .to_changes_view.should == changes_view
    diff_view2  .to_changes_view.should == changes_view
    changes_view.to_changes_view.should == changes_view
    chart_view  .to_changes_view.should == changes_view

    day_view    .to_chart_view.should == chart_view
    week_view   .to_chart_view.should == chart_view
    diff_view1  .to_chart_view.should == chart_view
    diff_view2  .to_chart_view.should == chart_view
    changes_view.to_chart_view.should == chart_view
    chart_view  .to_chart_view.should == chart_view
  end

  should "return first day correctly" do
    day_view.first_day.should == day1
    Concov::DayView.new(Date.parse("20090102")).first_day.should == day1
    Concov::DayView.new(Date.parse("20081231")).first_day.should ==
      Date.parse("20081201")
  end

  should "convert to path" do
    day_view    .to_path.should == "20090101"
    week_view   .to_path.should == "w20090101"
    diff_view1  .to_path.should == "d20090101"
    diff_view2  .to_path.should == "20081201d20090101"
    changes_view.to_path.should == "c20090101"
    chart_view  .to_path.should == "g20090101"
  end

  should "convert to show" do
    day_view    .to_show.should == "2009/01/01"
    week_view   .to_show.should == "2008/12/26 - 2009/01/01"
    changes_view.to_show.should == "2009/01/01"
    chart_view  .to_show.should == "2009/01/01"
    diff_view1  .to_show.should == "2009/01/01 (cf. 2008/12/31)"
    diff_view2  .to_show.should == "2009/01/01 (cf. 2008/12/01)"
  end

  should "return related views" do
    first = Date.parse("20080101")
    last  = Date.parse("20100101")

    day_view.related_views(first, last).should ==
      [Concov::DayView.new(first),
       Concov::DayView.new(Date.parse("20081225")),
       Concov::DayView.new(Date.parse("20081231")),
       Concov::DayView.new(Date.parse("20090102")),
       Concov::DayView.new(Date.parse("20090108")),
       Concov::DayView.new(last)]

    week_view.related_views(first, last).should ==
      [Concov::WeekView.new(first),
       Concov::WeekView.new(Date.parse("20081225")),
       Concov::WeekView.new(Date.parse("20081231")),
       Concov::WeekView.new(Date.parse("20090102")),
       Concov::WeekView.new(Date.parse("20090108")),
       Concov::WeekView.new(last)]

    diff_view1.related_views(first, last, :base).should ==
      [Concov::DiffView.new(first                 , day1),
       Concov::DiffView.new(Date.parse("20081224"), day1),
       Concov::DiffView.new(Date.parse("20081230"), day1),
       Concov::DayView.new(day1),
       Concov::DiffView.new(Date.parse("20090107"), day1),
       Concov::DiffView.new(last                  , day1)]

    diff_view1.related_views(first, last, :date).should ==
      [Concov::DiffView.new(Date.parse("20081231"), first),
       Concov::DiffView.new(Date.parse("20081231"), Date.parse("20081225")),
       Concov::DayView.new(Date.parse("20081231")),
       Concov::DiffView.new(Date.parse("20081231"), Date.parse("20090102")),
       Concov::DiffView.new(Date.parse("20081231"), Date.parse("20090108")),
       Concov::DiffView.new(Date.parse("20081231"), last)]

    diff_view2.related_views(first, last, :base).should ==
      [Concov::DiffView.new(first                 , day1),
       Concov::DiffView.new(Date.parse("20081124"), day1),
       Concov::DiffView.new(Date.parse("20081130"), day1),
       Concov::DiffView.new(Date.parse("20081202"), day1),
       Concov::DiffView.new(Date.parse("20081208"), day1),
       Concov::DiffView.new(last                  , day1)]

    diff_view2.related_views(first, last, :date).should ==
      [Concov::DiffView.new(Date.parse("20081201"), first),
       Concov::DiffView.new(Date.parse("20081201"), Date.parse("20081225")),
       Concov::DiffView.new(Date.parse("20081201"), Date.parse("20081231")),
       Concov::DiffView.new(Date.parse("20081201"), Date.parse("20090102")),
       Concov::DiffView.new(Date.parse("20081201"), Date.parse("20090108")),
       Concov::DiffView.new(Date.parse("20081201"), last)]

    changes_view.related_views(first, last).should ==
      [Concov::ChangesView.new(first),
       Concov::ChangesView.new(Date.parse("20081225")),
       Concov::ChangesView.new(Date.parse("20081231")),
       Concov::ChangesView.new(Date.parse("20090102")),
       Concov::ChangesView.new(Date.parse("20090108")),
       Concov::ChangesView.new(last)]

    chart_view.related_views(first, last).should ==
      [Concov::ChartView.new(first),
       Concov::ChartView.new(Date.parse("20081225")),
       Concov::ChartView.new(Date.parse("20081231")),
       Concov::ChartView.new(Date.parse("20090102")),
       Concov::ChartView.new(Date.parse("20090108")),
       Concov::ChartView.new(last)]
  end
end
