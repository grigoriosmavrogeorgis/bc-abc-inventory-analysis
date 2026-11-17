namespace GMSoft.ABCInventoryAnalysis.Tests;

using System.IO;
using System.Threading;

/// <summary>
/// Manually bound subscribers that keep tests away from the client and the task scheduler:
/// Excel workbooks are counted instead of downloaded, and job queue entries get a task ID without a real task.
/// </summary>
codeunit 50011 "GSO ABC Test Subscribers"
{
    EventSubscriberInstance = Manual;

    var
        WorkbooksOpened: Integer;
        TasksScheduled: Integer;

    procedure GetWorkbooksOpened(): Integer
    begin
        exit(WorkbooksOpened);
    end;

    procedure GetTasksScheduled(): Integer
    begin
        exit(TasksScheduled);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Excel Buffer", 'OnBeforeOpenUsingDocumentService', '', false, false)]
    local procedure CountWorkbookInsteadOfOpening(FileNameServer: Text; FileName: Text; var Result: Boolean; var IsHandled: Boolean)
    begin
        WorkbooksOpened += 1;
        Result := true;
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Job Queue Entry", 'OnBeforeScheduleTask', '', false, false)]
    local procedure ReturnTaskIdWithoutScheduling(var JobQueueEntry: Record "Job Queue Entry"; var TaskGUID: Guid; var IsHandled: Boolean)
    begin
        TasksScheduled += 1;
        TaskGUID := CreateGuid();
        IsHandled := true;
    end;
}
