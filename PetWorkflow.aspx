<%@ Page Title="Spend Request" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true"
    CodeBehind="PetWorkflow.aspx.cs" Inherits="DFM_BPM.Forms.PetWorkflow"
    MaintainScrollPositionOnPostback="true" %>

<asp:Content ID="HeadCt" ContentPlaceHolderID="HeadContent" runat="server">
<link href="<%= ResolveUrl("~/Content/bootstrap-icons.css") %>" rel="stylesheet" />
<link href="<%= ResolveUrl("~/Content/select2.min.css") %>" rel="stylesheet" />
<style>
/* ---- PET Workflow ---- */
.pet-nav-tabs > li.active > a { background:#1a3c5e !important; color:#fff !important; border-color:#1a3c5e !important; }
.pet-nav-tabs > li > a { font-weight:700; font-size:.88em; }
.stepper { display:flex; gap:0; margin-bottom:18px; }
.step { flex:1; text-align:center; padding:8px 4px; font-size:.78em; font-weight:700;
        background:#f1f5f9; border:1px solid #cbd5e1; color:#64748b; position:relative; }
.step.active { background:#1a3c5e; color:#fff; border-color:#1a3c5e; }
.step.done   { background:#059669; color:#fff; border-color:#059669; }
.step::after { content:'>'; position:absolute; right:-12px; top:50%; transform:translateY(-50%);
               font-size:1.4em; z-index:2; color:#94a3b8; }
.step:last-child::after { display:none; }
.workflow-breadcrumb { margin-bottom:12px; background:#fff; border:1px solid #dbe5f1; border-radius:10px; padding:8px; }
.workflow-breadcrumb .step { min-height:38px; display:flex; align-items:center; justify-content:center; }
.workflow-breadcrumb .step.rejected { background:#fee2e2; color:#991b1b; border-color:#ef4444; }
.project-overview-stack { margin-left:0; margin-right:0; }
.project-overview-stack .col-md-6 { width:100%; float:none; padding-left:0; padding-right:0; }
.project-overview-stack .card-panel { margin-bottom:14px; }
.project-overview-stack .card-panel-body { overflow-x:auto; }
.pet-line-tbl th { background:#1a3c5e; color:#fff; padding:6px 8px; font-size:.78em; white-space:nowrap; }
.pet-line-tbl td { padding:4px 6px; border:1px solid #e2e8f0; vertical-align:middle; font-size:.82em; }
.spend-line-entry { margin-top:14px; }
.spend-line-entry .card-panel-body { padding:14px; }
.spend-line-entry .line-form-actions { display:flex; align-items:flex-end; gap:8px; flex-wrap:wrap; }
.total-bar { background:#f8fafc; border:1px solid #e2e8f0; border-radius:6px; padding:8px 14px;
             display:flex; gap:20px; font-size:.82em; font-weight:700; margin-top:8px; flex-wrap:wrap; }
.total-bar span { color:#64748b; } .total-bar strong { color:#1a3c5e; }
.decision-panel { background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:18px; }
.decision-btns  { display:flex; gap:8px; flex-wrap:wrap; margin-top:12px; }
.amt-panel { background:linear-gradient(135deg,#dbeafe,#eff6ff); border:1px solid #93c5fd; border-radius:8px; padding:12px; margin-bottom:10px; }
.amt-panel.opex-panel { background:linear-gradient(135deg,#d1fae5,#ecfdf5); border-color:#6ee7b7; }
.amt-panel-title { font-size:.75em; font-weight:700; text-transform:uppercase; letter-spacing:.3px; color:#64748b; margin-bottom:6px; }
.bgt-budget   { background:#eff6ff; border-left:3px solid #3b82f6; border-radius:4px; padding:6px 8px; }
.bgt-utilized { background:#fff7ed; border-left:3px solid #f59e0b; border-radius:4px; padding:6px 8px; }
.bgt-avail    { background:#f0fdf4; border-left:3px solid #22c55e; border-radius:4px; padding:6px 8px; }
.bgt-locked   { background:#fef2f2; border-left:3px solid #ef4444; border-radius:4px; padding:6px 8px; }
.bgt-net      { background:#f5f3ff; border-left:3px solid #8b5cf6; border-radius:4px; padding:6px 8px; }
.budget-label { font-size:.72em; font-weight:700; text-transform:uppercase; color:#64748b; }
.budget-val   { font-size:.95em; font-weight:800; color:#1e293b; }
.budget-panel-row { display:grid; grid-template-columns:repeat(5,1fr); gap:8px; margin-top:6px; }
.budget-panel-row-4 { display:grid; grid-template-columns:repeat(4,1fr); gap:8px; margin-top:10px; padding-top:10px; border-top:1px dashed #cbd5e1; }
.jira-detail-tbl td { border:1px solid #e5e7eb; padding:7px 12px; vertical-align:middle; font-size:.87em; }
.jira-detail-tbl td.lbl { background:#f8f9fa; font-weight:700; color:#374151; width:18%; white-space:nowrap; }
.jira-detail-tbl td.lbl i.bi { color:#2563eb; margin-right:5px; }
.jira-detail-tbl td.val { background:#fff; width:32%; }
.attach-item { display:inline-flex; align-items:center; gap:6px; background:#f0f9ff; border:1px solid #bae6fd;
               border-radius:6px; padding:4px 10px; margin:2px; font-size:.82em; }
.approver-impact { background:linear-gradient(135deg,#fefce8,#fef9c3); border:1px solid #facc15;
                   border-radius:8px; padding:12px; margin-bottom:10px; }
.ps-card { background:#fff; border:1px solid #e2e8f0; border-radius:8px; padding:14px 16px; margin-bottom:12px; }
.ps-card-title { font-weight:700; color:#1e3a5f; margin-bottom:4px; font-size:.92em; }
.ps-radio-group { display:flex; gap:10px; flex-wrap:wrap; }
.ps-radio-btn { flex:1; min-width:120px; }
.ps-radio-btn input[type=radio] { display:none; }
.ps-radio-btn label { display:block; text-align:center; cursor:pointer; padding:8px 6px; border-radius:6px;
                      border:2px solid #e2e8f0; font-weight:600; background:#f8fafc; }
.ps-radio-btn input[type=radio]:checked + label.low    { border-color:#22c55e; background:#dcfce7; color:#15803d; }
.ps-radio-btn input[type=radio]:checked + label.medium { border-color:#f59e0b; background:#fef3c7; color:#92400e; }
.ps-radio-btn input[type=radio]:checked + label.high   { border-color:#ef4444; background:#fee2e2; color:#991b1b; }
.ps-result-panel { border-radius:10px; padding:16px 20px; margin-top:16px; text-align:center; display:none; }
.ps-result-panel.visible { display:block; }
.ps-result-badge { font-size:3em; font-weight:900; letter-spacing:2px; margin-bottom:4px; }
.ps-score-bar { height:10px; border-radius:5px; background:#e2e8f0; margin:10px 0; overflow:hidden; }
.ps-score-fill { height:100%; border-radius:5px; }
.ps-result-xs { background:linear-gradient(135deg,#ecfdf5,#d1fae5); border:2px solid #22c55e; color:#14532d; }
.ps-result-s  { background:linear-gradient(135deg,#f0fdf4,#bbf7d0); border:2px solid #4ade80; color:#166634; }
.ps-result-m  { background:linear-gradient(135deg,#fefce8,#fef9c3); border:2px solid #facc15; color:#713f12; }
.ps-result-l  { background:linear-gradient(135deg,#fff7ed,#ffedd5); border:2px solid #fb923c; color:#7c2d12; }
.ps-result-xl { background:linear-gradient(135deg,#fef2f2,#fee2e2); border:2px solid #f87171; color:#7f1d1d; }
/* ---- Project Details table ---- */
.proj-detail-tbl { width:100%; border-collapse:collapse; }
.proj-detail-tbl td { border:1px solid #cbd5e1; padding:7px 10px; vertical-align:middle; font-size:.85em; }
.proj-detail-tbl td.lbl {
    /* background: linear-gradient(135deg, #1e3a5f, #2563eb); */
    color: #1e40af;
    font-weight: 700;
    width: 16%;
    white-space: nowrap;
    /* border-color: grey; */
}
.proj-detail-tbl td.lbl i.bi { margin-right:4px; opacity:.85; }
.proj-detail-tbl td.val { background:#f8fafc; color:#1e293b; width:17%; }
.proj-detail-tbl tr:nth-child(odd)  td.val { background:#f0f5ff; }
.proj-detail-tbl tr:nth-child(even) td.val { background:#eef9f3; }
.proj-detail-tbl tr:hover td.val   { background:#dbeafe; }
.proj-detail-tbl tr:hover td.lbl   { background:#dbeafe; }
/* ---- Sizing history size badges ---- */
.ps-size-badge { display:inline-block; padding:2px 9px; border-radius:20px; font-weight:800; font-size:.85em; }
.size-xs  { background:#dcfce7; color:#14532d; border:1px solid #22c55e; }
.size-s   { background:#d1fae5; color:#065f46; border:1px solid #34d399; }
.size-m   { background:#fef9c3; color:#713f12; border:1px solid #facc15; }
.size-l   { background:#ffedd5; color:#7c2d12; border:1px solid #fb923c; }
.size-xl  { background:#fee2e2; color:#7f1d1d; border:1px solid #f87171; }
/* ---- Assessment history grid ---- */
.ps-history-grid th  { background:#1e3a5f !important; color:#fff !important; font-size:.8em; padding:6px 8px; white-space:nowrap; }
.ps-history-grid td  { font-size:.82em; padding:5px 8px; vertical-align:middle; }
.ps-history-grid tr:nth-child(odd)  td { background:#f0f5ff; }
.ps-history-grid tr:nth-child(even) td { background:#ffffff; }
.ps-history-grid tr:hover td { background:#dbeafe; }
/* ---- Financial grids in Project Details ---- */
.dfm-table th { background:#1e3a5f !important; color:#fff !important; font-size:.8em; padding:6px 8px; white-space:nowrap; }
.dfm-table td { font-size:.82em; padding:5px 8px; vertical-align:middle; }
.dfm-table tr:nth-child(odd)  td { background:#fafbff; }
.dfm-table tr:nth-child(even) td { background:#ffffff; }
.dfm-table tr:hover td { background:#dbeafe; }

/* ---- Panel Color Coding (per Requirement/colorCode.csv) ---- */
.card-panel { border-radius:8px; overflow:hidden; border:1px solid #e2e8f0; }
.card-panel-hdr { padding:12px 14px; font-weight:700; font-size:.95em; display:flex; align-items:center; gap:8px; }
.card-panel-body { padding:0; }

/* 1. Spend Request Details — Main Request Information */
.card-panel.panel-spend-request { border-color:#B4C7E7; background:#F5F9FF; }
.card-panel.panel-spend-request .card-panel-hdr { background:#F5F9FF; color:#2F5597; border-bottom:2px solid #2F5597; }
.card-panel.panel-spend-request .dfm-table th,
.card-panel.panel-spend-request .pet-line-tbl th { background:#2F5597 !important; color:#fff; }

/* 2. Budget Line Items — Budget Details */
.card-panel.panel-budget-line-items { border-color:#C6E0B4; background:#F6FBF4; }
.card-panel.panel-budget-line-items .card-panel-hdr { background:#F6FBF4; color:#548235; border-bottom:2px solid #548235; }
.card-panel.panel-budget-line-items .dfm-table th,
.card-panel.panel-budget-line-items .pet-line-tbl th { background:#548235 !important; color:#fff; }

/* 3. Budget / Invoice — Invoice Details */
.card-panel.panel-budget-invoice { border-color:#F4B183; background:#FFF8F2; }
.card-panel.panel-budget-invoice .card-panel-hdr { background:#FFF8F2; color:#C55A11; border-bottom:2px solid #C55A11; }
.card-panel.panel-budget-invoice .dfm-table th,
.card-panel.panel-budget-invoice .pet-line-tbl th { background:#C55A11 !important; color:#fff; }

/* 4. Approval History — Workflow History */
.card-panel.panel-approval-history { border-color:#FFE699; background:#FFFBEA; }
.card-panel.panel-approval-history .card-panel-hdr { background:#FFFBEA; color:#7F6000; border-bottom:2px solid #7F6000; }
.card-panel.panel-approval-history .dfm-table th { background:#7F6000 !important; color:#fff; }

/* 5. Comments — User Comments (applied to comment input boxes, not a grid) */
.comments-box { background:#FAFAFA; border:1px solid #D9D9D9; border-left:4px solid #5B5B5B; border-radius:6px; padding:10px 12px; }
.comments-box > label { color:#5B5B5B; font-weight:700; }

/* 6. Attachments — Uploaded Documents */
.card-panel.panel-attachments { border-color:#9DC3E6; background:#F3F9FD; }
.card-panel.panel-attachments .card-panel-hdr { background:#F3F9FD; color:#1F4E78; border-bottom:2px solid #1F4E78; }

/* 7. Audit Trail — System Logs (Sizing Assessment History grid) */
.card-panel.panel-audit-trail { border-color:#D9C2E9; background:#FAF5FF; }
.card-panel.panel-audit-trail .card-panel-hdr { background:#FAF5FF; color:#7030A0; border-bottom:2px solid #7030A0; }
.ps-history-grid.audit-trail-grid th  { background:#7030A0 !important; color:#fff !important; }
.ps-history-grid.audit-trail-grid tr:nth-child(odd)  td { background:#FAF5FF; }
.ps-history-grid.audit-trail-grid tr:nth-child(even) td { background:#ffffff; }
.ps-history-grid.audit-trail-grid tr:hover td { background:#D9C2E9; }

.workflow-frame-modal .modal-dialog { width:95%; max-width:1180px; }
.workflow-frame-modal .modal-body { padding:0; height:78vh; overflow:hidden; }
.workflow-frame-modal iframe { width:100%; height:100%; border:0; display:block; background:#fff; }

<% if (HostCloseOnInnerModalClose) { %>
html, body { background:transparent !important; overflow:hidden !important; }
.ux-page-head,
.workflow-breadcrumb,
.pet-nav-tabs,
.tab-content,
.next-step-message,
.next-step-toast { display:none !important; }
.modal-dialog { margin-top:44px; }
<% } %>

.dfm-table tr:nth-child(even) td { background:#ffffff; }
.dfm-table tr:hover td { background:#eff6ff; }
.dfm-table td.text-right { text-align:right; font-weight:600; color:#1e3a5f; }
</style>
</asp:Content>

<asp:Content ID="MainCt" ContentPlaceHolderID="MainContent" runat="server">
<div class="ux-page-head">
    <div>
        <div class="ux-title"><i class="bi bi-file-earmark-text"></i> Spend Request</div>
        <div class="ux-subtitle">Create, review, approve, and track budget or invoice details from one workflow view.
            <% if (!string.IsNullOrEmpty(PetRefNo)) { %><span class="ux-muted-pill"><%= Server.HtmlEncode(PetRefNo) %></span><% } %>
        </div>
    </div>
    <div class="ux-actions">
        <% if (CanDeletePet) { %>
        <asp:Button ID="btnDeleteThisPet" runat="server" CssClass="btn btn-sm btn-danger"
            Text="Delete This Spend Request" OnClientClick="$('#petFormDelModal').modal('show');return false;"
            CausesValidation="false" />
        <% } %>
    </div>
</div>

<asp:Label ID="lblMsg" runat="server" CssClass="alert alert-info" Visible="false" />
<asp:HiddenField ID="hfPetFormId" runat="server" Value="0" />
<asp:HiddenField ID="hfActiveTab" runat="server" Value="pet" />

<div class="stepper workflow-breadcrumb">
    <div class="step <%= StepClass(1) %>">Draft</div>
    <div class="step <%= StepClass(2) %>">Pending Review</div>
    <div class="step <%= StepClass(3) %>">Pending Approval</div>
    <div class="step <%= StepClass(4) %>">Approved</div>
    <div class="step <%= StepClass(5) %>">Budget/Invoice</div>
</div>

<ul class="nav nav-tabs pet-nav-tabs" role="tablist">
    <li class="<%= TabActive("pet") %>">      <a href="#tabPet"      data-toggle="tab"><i class="bi bi-file-earmark-text"></i> Request</a></li>
    <li class="<%= TabActive("project") %>">  <a href="#tabProject"  data-toggle="tab"><i class="bi bi-folder2-open"></i> Project Details</a></li>
    <li class="<%= TabActive("sizing") %>">   <a href="#tabSizing"   data-toggle="tab"><i class="bi bi-rulers"></i> Project Sizing</a></li>
    <li class="<%= TabActive("approval") %>"> <a href="#tabApproval" data-toggle="tab"><i class="bi bi-check2-circle"></i> Approval</a></li>
    <li class="<%= TabActive("import") %>">   <a href="#tabImport"   data-toggle="tab"><i class="bi bi-file-earmark-arrow-up"></i> CSV Import</a></li>
    <% if (ShowBudgetTab) { %>
    <li class="<%= TabActive("budget") %>">   <a href="#tabBudget"   data-toggle="tab"><i class="bi bi-cash-coin"></i> Budget/Invoice</a></li>
    <% } %>
</ul>

<div class="tab-content" style="padding-top:14px;">

<!-- ================================================================ TAB 1: PET ================================================================ -->
<div class="tab-pane <%= TabPane("pet") %>" id="tabPet">

    <div class="card-panel panel-spend-request" style="margin-bottom:14px;">
        <div class="card-panel-hdr"><i class="bi bi-pencil-square"></i> Spend Request Registration</div>
        <div class="card-panel-body">
            <table class="table jira-detail-tbl">
                <tbody>
                    <% if (CurrentPetFormId > 0) { %>
                    <tr>
                        <td class="lbl"><i class="bi bi-person-circle"></i>Requestor</td>
                        <td class="val"><%= Server.HtmlEncode(RequestorFullName ?? RequestorUsername) %></td>
                        <td class="lbl"><i class="bi bi-calendar-event"></i>Requested On</td>
                        <td class="val"><%= Server.HtmlEncode(RequestedDate) %></td>
                    </tr>
                    <% } %>
                    <tr>
                        <td class="lbl"><i class="bi bi-key"></i>Registered Project <span style="color:#dc2626;">*</span></td>
                        <td class="val">
                            <asp:DropDownList ID="ddlProject" runat="server" CssClass="form-control select2-enable"
                                AutoPostBack="true" OnSelectedIndexChanged="ddlProject_Changed" />
                            <% if (!IsProjectLocked) { %>
                            <small style="color:#64748b;">Not seeing your project?
                                <a href="<%= ResolveUrl("~/Forms/ProjectRegistration.aspx") %>" target="_blank">Register it first</a>.</small>
                            <% } %>
                        </td>
                        <td class="lbl"><i class="bi bi-file-earmark-text"></i>Project Name</td>
                        <td class="val">
                            <asp:TextBox ID="txtProjectName" runat="server" CssClass="form-control" ReadOnly="true" />
                        </td>
                    </tr>
                    <tr>
                        <td class="lbl"><i class="bi bi-briefcase"></i>Type <span style="color:#dc2626;">*</span></td>
                        <td class="val">
                            <asp:DropDownList ID="ddlType" runat="server" CssClass="form-control"
                                AutoPostBack="true" OnSelectedIndexChanged="ddlType_Changed">
                                <asp:ListItem Value="">-- Select --</asp:ListItem>
                                <asp:ListItem Value="CAPEX">CAPEX</asp:ListItem>
                                <asp:ListItem Value="OPEX">OPEX</asp:ListItem>
                            </asp:DropDownList>
                        </td>
                        <td class="lbl"><i class="bi bi-currency-dollar"></i>Budget Source <small style="color:#64748b;">(optional)</small></td>
                        <td class="val">
                            <asp:DropDownList ID="ddlBudgetSource" runat="server" CssClass="form-control select2-enable"
                                AutoPostBack="true" OnSelectedIndexChanged="ddlBudgetSource_Changed" />
                        </td>
                    </tr>
                    <tr>
                        <td class="lbl"><i class="bi bi-person-check"></i>Reviewer <span style="color:#dc2626;">*</span></td>
                        <td class="val">
                            <asp:DropDownList ID="ddlReviewer" runat="server" CssClass="form-control select2-enable">
                                <asp:ListItem Value="">-- Select Reviewer --</asp:ListItem>
                            </asp:DropDownList>
                        </td>
                        <td class="lbl"><i class="bi bi-person-badge"></i>Approver <span style="color:#dc2626;">*</span></td>
                        <td class="val">
                            <asp:DropDownList ID="ddlApprover" runat="server" CssClass="form-control select2-enable" />
                        </td>
                    </tr>
                    <tr>
                        <td class="lbl" colspan="1"><i class="bi bi-card-text"></i>Title / Subject <span style="color:#dc2626;">*</span></td>
                        <td class="val" colspan="3">
                            <asp:TextBox ID="txtTitle" runat="server" CssClass="form-control" />
                        </td>
                    </tr>
                </tbody>
            </table>

            <!-- Budget source detail panels -->
            <asp:Panel ID="pnlCapexAmt" runat="server" Visible="false">
                <div class="amt-panel">
                    <div class="amt-panel-title"><i class="bi bi-currency-dollar"></i> CAPEX Budget &ndash; <asp:Literal ID="litCapexSourceId" runat="server" /></div>
                    <div class="budget-panel-row-4">
                        <div class="bgt-budget">  <div class="budget-label">Budgeted</div>  <div class="budget-val"><asp:Literal ID="litCapexBudget"    runat="server" Text="0" /></div></div>
                        <div class="bgt-utilized"><div class="budget-label">Utilized</div>  <div class="budget-val"><asp:Literal ID="litCapexUtil"      runat="server" Text="0" /></div></div>
                        <div class="bgt-locked">  <div class="budget-label">BPM Locked</div><div class="budget-val"><asp:Literal ID="litCapexLocked"    runat="server" Text="0" /></div></div>
                        <div class="bgt-avail">   <div class="budget-label">Available</div>  <div class="budget-val"><asp:Literal ID="litCapexAvail"     runat="server" Text="0" /></div></div>
                    </div>
                    <div class="budget-panel-row-4">
                        <div class="bgt-budget">  <div class="budget-label">Total PET Cost</div>  <div class="budget-val"><asp:Literal ID="litCapexTotalPetCost"    runat="server" Text="0" /></div></div>
                        <div class="bgt-utilized"><div class="budget-label">Invoice Cost</div>    <div class="budget-val"><asp:Literal ID="litCapexInvoiceCost"     runat="server" Text="0" /></div></div>
                        <div class="bgt-avail">   <div class="budget-label">Invoice Settled</div> <div class="budget-val"><asp:Literal ID="litCapexInvoiceSettled" runat="server" Text="0" /></div></div>
                        <div class="bgt-locked">  <div class="budget-label">Pending</div>         <div class="budget-val"><asp:Literal ID="litCapexInvoicePending"  runat="server" Text="0" /></div></div>
                    </div>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlOpexAmt" runat="server" Visible="false">
                <div class="amt-panel opex-panel">
                    <div class="amt-panel-title"><i class="bi bi-receipt"></i> OPEX Budget &ndash; <asp:Literal ID="litOpexSourceId" runat="server" /></div>
                    <div class="budget-panel-row">
                        <div class="bgt-budget">  <div class="budget-label">Budgeted</div>  <div class="budget-val"><asp:Literal ID="litOpexBudget"    runat="server" Text="0" /></div></div>
                        <div class="bgt-utilized"><div class="budget-label">Utilized</div>  <div class="budget-val"><asp:Literal ID="litOpexUtil"      runat="server" Text="0" /></div></div>
                        <div class="bgt-locked">  <div class="budget-label">BPM Locked</div><div class="budget-val"><asp:Literal ID="litOpexLocked"    runat="server" Text="0" /></div></div>
                        <div class="bgt-avail">   <div class="budget-label">Available</div>  <div class="budget-val"><asp:Literal ID="litOpexAvail"     runat="server" Text="0" /></div></div>
                        <div class="bgt-net">     <div class="budget-label">Contracts</div>  <div class="budget-val" style="font-size:.75em;"><asp:Literal ID="litOpexContracts" runat="server" /></div></div>
                    </div>
                    <div class="budget-panel-row-4">
                        <div class="bgt-budget">  <div class="budget-label">Total PET Cost</div>  <div class="budget-val"><asp:Literal ID="litOpexTotalPetCost"    runat="server" Text="0" /></div></div>
                        <div class="bgt-utilized"><div class="budget-label">Invoice Cost</div>    <div class="budget-val"><asp:Literal ID="litOpexInvoiceCost"     runat="server" Text="0" /></div></div>
                        <div class="bgt-avail">   <div class="budget-label">Invoice Settled</div> <div class="budget-val"><asp:Literal ID="litOpexInvoiceSettled" runat="server" Text="0" /></div></div>
                        <div class="bgt-locked">  <div class="budget-label">Pending</div>         <div class="budget-val"><asp:Literal ID="litOpexInvoicePending"  runat="server" Text="0" /></div></div>
                    </div>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlLinesGrid" runat="server" Visible="false" CssClass="card-panel panel-spend-request spend-line-entry">
                <div class="card-panel-hdr">
                    <i class="bi bi-list-ul"></i> <%= CanEditSpendLines ? "Add Spend Line" : "Spend Request Line Items" %>
                    <small style="font-weight:400;color:#2563eb;">&mdash; <%= Server.HtmlEncode(string.IsNullOrEmpty(PetRefNo) ? "Staged until Save Request" : PetRefNo) %></small>
                </div>
                <div class="card-panel-body">
                    <% if (CanEditSpendLines) { %>
                    <asp:HiddenField ID="hfEditLineId" runat="server" Value="" />
                    <div class="form-grid-4">
                        <div class="form-group">
                            <label>Expenditure Head</label>
                            <asp:DropDownList ID="ddlExpHead" runat="server" CssClass="form-control">
                                <asp:ListItem Value="CAPEX">CAPEX</asp:ListItem>
                                <asp:ListItem Value="OPEX">OPEX</asp:ListItem>
                            </asp:DropDownList>
                        </div>
                        <div class="form-group col-span-2">
                            <label>Topic / Item <span style="color:#dc2626;">*</span></label>
                            <asp:TextBox ID="txtLineTopic" runat="server" CssClass="form-control" />
                        </div>
                        <div class="form-group">
                            <label>Vendor <span style="color:#dc2626;">*</span></label>
                            <asp:DropDownList ID="ddlLineVendor" runat="server" CssClass="form-control" />
                        </div>
                        <div class="form-group">
                            <label>Cost Type <span style="color:#dc2626;">*</span></label>
                            <asp:DropDownList ID="ddlLineCostType" runat="server" CssClass="form-control" />
                        </div>
                        <div class="form-group">
                            <label>GL Number <small style="color:#94a3b8;">(optional)</small></label>
                            <asp:DropDownList ID="ddlLineGL" runat="server" CssClass="form-control" />
                        </div>
                        <div class="form-group">
                            <label>Currency</label>
                            <asp:DropDownList ID="ddlLineCcy" runat="server" CssClass="form-control" />
                        </div>
                        <div class="form-group">
                            <label>Units</label>
                            <asp:TextBox ID="txtLineUnits" runat="server" CssClass="form-control" Text="1" />
                        </div>
                        <div class="form-group">
                            <label>Unit Price (FCY)</label>
                            <asp:TextBox ID="txtLineUnitPrice" runat="server" CssClass="form-control" Text="0" />
                        </div>
                        <div class="form-group">
                            <label>FCY Amount</label>
                            <asp:TextBox ID="txtLineAmtFCY" runat="server" CssClass="form-control" Text="0" ReadOnly="true" />
                        </div>
                        <div class="form-group">
                            <label>AED Amount</label>
                            <asp:TextBox ID="txtLineAmtLCY" runat="server" CssClass="form-control" Text="0" ReadOnly="true" />
                        </div>
                        <div class="form-group">
                            <label>Contingency %</label>
                            <asp:TextBox ID="txtLineConting" runat="server" CssClass="form-control" Text="0" />
                        </div>
                        <div class="form-group col-span-4">
                            <label>Description</label>
                            <asp:TextBox ID="txtLineDesc" runat="server" CssClass="form-control" TextMode="MultiLine" Rows="2" />
                        </div>
                        <div class="form-group col-span-4 line-form-actions">
                            <asp:Button ID="btnSaveLine" runat="server" CssClass="btn btn-success" Text="Add Spend Line" OnClick="btnSaveLine_Click" />
                            <asp:Button ID="btnCancelLine" runat="server" CssClass="btn btn-default" Text="Cancel Edit" OnClick="btnCancelLine_Click" CausesValidation="false" Visible="false" />
                        </div>
                    </div>
                    <% } %>
                    <div style="overflow-x:auto;">
                        <asp:GridView ID="gvLines" runat="server" AutoGenerateColumns="false"
                            CssClass="dfm-table pet-line-tbl" GridLines="None"
                            OnRowCommand="gvLines_RowCommand"
                            AllowPaging="true" PageSize="10" OnPageIndexChanging="gvLines_PageIndexChanging"
                            EmptyDataText="No spend lines staged yet.">
                            <PagerStyle CssClass="dfm-pager" HorizontalAlign="Center" />
                            <PagerSettings Mode="NumericFirstLast" PageButtonCount="5" FirstPageText="&laquo;" LastPageText="&raquo;" />
                            <Columns>
                                <asp:BoundField DataField="SerialNo"    HeaderText="#"          ItemStyle-Width="30px" />
                                <asp:BoundField DataField="ExpHead"     HeaderText="Head"       ItemStyle-Width="60px" />
                                <asp:BoundField DataField="Topic"       HeaderText="Topic" />
                                <asp:BoundField DataField="VendorName"  HeaderText="Vendor" />
                                <asp:BoundField DataField="CostType"    HeaderText="Cost Type" />
                                <asp:BoundField DataField="Units"       HeaderText="Units"      DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                                <asp:BoundField DataField="UnitPrice"   HeaderText="Unit Price" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                                <asp:BoundField DataField="BaseCurrency" HeaderText="CCY" />
                                <asp:BoundField DataField="AmtFCY"      HeaderText="FCY Amt"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                                <asp:BoundField DataField="AmtLCY"      HeaderText="AED Amt"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                                <asp:BoundField DataField="ContingencyPct" HeaderText="Cont.%"  DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                                <asp:BoundField DataField="FinalAmtLCY" HeaderText="Final AED"  DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                                <asp:BoundField DataField="GLNumber"    HeaderText="GL#" />
                                <asp:TemplateField HeaderText="Action" ItemStyle-Width="94px" ItemStyle-CssClass="action-cell">
                                    <ItemTemplate>
                                        <div class="gv-acts">
                                            <asp:LinkButton runat="server" CssClass="btn btn-xs btn-primary"
                                                Visible='<%# CanEditSpendLines %>'
                                                CommandName="EditLine" CommandArgument='<%# Eval("LineID") %>'>
                                                <i class="bi bi-pencil"></i> Edit
                                            </asp:LinkButton>
                                            <asp:LinkButton runat="server" CssClass="btn btn-xs btn-danger"
                                                Visible='<%# CanEditSpendLines %>'
                                                CommandName="DelLine" CommandArgument='<%# Eval("LineID") %>'
                                                OnClientClick="return confirm('Delete this spend line?')">
                                                <i class="bi bi-trash"></i> Delete
                                            </asp:LinkButton>
                                        </div>
                                    </ItemTemplate>
                                </asp:TemplateField>
                            </Columns>
                        </asp:GridView>
                        <div class="total-bar">
                            <span>Lines: <strong><asp:Literal ID="litLineCount"  runat="server" Text="0" /></strong></span>
                            <span>Total AED (before cont.): <strong><asp:Literal ID="litTotalLCY"   runat="server" Text="0.00" /></strong></span>
                            <span>Total Final AED: <strong><asp:Literal ID="litTotalFinal" runat="server" Text="0.00" /></strong></span>
                        </div>
                    </div>
                </div>
            </asp:Panel>

            <% if (CanEditSpendLines) { %>
            <div class="ux-form-actions">
                <asp:Button ID="btnSaveHeader" runat="server" CssClass="btn btn-primary"
                    Text="Save Request" OnClick="btnSaveHeader_Click" />
            </div>
            <% } %>
        </div>
    </div>

    <!-- Project Overview — the Project is the main item: show all PET forms (incl. Draft) and Budget/Invoice for it -->
    <asp:Panel ID="pnlProjectOverview" runat="server" Visible="false">
    <div class="row project-overview-stack">
        <div class="col-md-6">
            <div class="card-panel panel-spend-request">
                <div class="card-panel-hdr"><i class="bi bi-file-earmark-text"></i> Spend Requests for this Project <small style="font-weight:400;color:#94a3b8;">(including Draft)</small></div>
                <div class="card-panel-body" style="padding:0;overflow-x:auto;">
                    <asp:GridView ID="gvProjectPets" runat="server" AutoGenerateColumns="false"
                        CssClass="dfm-table" GridLines="None" EmptyDataText="No Spend Requests yet for this project.">
                        <Columns>
                            <asp:BoundField DataField="PetRefNo"      HeaderText="Ref No" />
                            <asp:BoundField DataField="CapexOpexType" HeaderText="Type" />
                            <asp:BoundField DataField="Title"         HeaderText="Title" />
                            <asp:BoundField DataField="Status"        HeaderText="Status" />
                            <asp:BoundField DataField="CreatedBy"     HeaderText="Requestor" />
                            <asp:BoundField DataField="CreatedDate"   HeaderText="Created"  DataFormatString="{0:dd-MMM-yyyy}" />
                            <asp:BoundField DataField="TotalRequestedAED" HeaderText="Requested (AED)" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                            <asp:TemplateField HeaderText="Action">
                                <ItemTemplate>
                                    <a href='<%# ResolveUrl("~/Forms/PetWorkflow.aspx") + "?embed=1&id=" + Eval("PetFormID") %>' onclick="return petOpenWorkflowLink(this);" class="btn btn-xs btn-primary"><i class="bi bi-arrow-right-circle"></i> Open</a>
                                </ItemTemplate>
                            </asp:TemplateField>
                        </Columns>
                    </asp:GridView>
                </div>
            </div>
        </div>
    </div>
    <div class="row project-overview-stack" style="margin-top:14px;">
        <div class="col-md-6">
            <div class="card-panel panel-budget-line-items">
                <div class="card-panel-hdr"><i class="bi bi-cash-coin"></i> Budget for this Project <small style="font-weight:400;color:#2563eb;">&mdash; <%= Server.HtmlEncode(string.IsNullOrEmpty(PetRefNo) ? "(unsaved)" : PetRefNo) %></small></div>
                <div class="card-panel-body" style="padding:0;overflow-x:auto;">
                    <asp:GridView ID="gvProjectBudget" runat="server" AutoGenerateColumns="false"
                        CssClass="dfm-table" GridLines="None" EmptyDataText="No budget lines yet for this project.">
                        <Columns>
                            <asp:BoundField DataField="PetRefNo"      HeaderText="Request Ref" />
                            <asp:BoundField DataField="VendorName"    HeaderText="Vendor" />
                            <asp:BoundField DataField="Justification" HeaderText="Justification" />
                            <asp:BoundField DataField="Cost"           HeaderText="Cost" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                            <asp:BoundField DataField="Currency"       HeaderText="CCY" />
                            <asp:BoundField DataField="GLNumber"       HeaderText="GL" />
                            <asp:BoundField DataField="CamStatus"      HeaderText="CAM Status" />
                            <asp:BoundField DataField="LpoStatus"      HeaderText="LPO Status" />
                            <asp:BoundField DataField="InvoiceTotal"   HeaderText="Invoiced" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                            <asp:TemplateField HeaderText="Action">
                                <ItemTemplate>
                                    <a href='<%# ResolveUrl("~/Forms/PetWorkflow.aspx") + "?embed=1&id=" + Eval("PetFormID") + "&tab=budget" %>' onclick="return petOpenWorkflowLink(this);" class="btn btn-xs btn-primary"><i class="bi bi-arrow-right-circle"></i> Open</a>
                                </ItemTemplate>
                            </asp:TemplateField>
                        </Columns>
                    </asp:GridView>
                </div>
            </div>
        </div>
        <div class="col-md-6">
            <div class="card-panel panel-budget-invoice">
                <div class="card-panel-hdr"><i class="bi bi-receipt"></i> Invoice for this Project <small style="font-weight:400;color:#2563eb;">&mdash; <%= Server.HtmlEncode(string.IsNullOrEmpty(PetRefNo) ? "(unsaved)" : PetRefNo) %></small></div>
                <div class="card-panel-body" style="padding:0;overflow-x:auto;">
                    <asp:GridView ID="gvProjectInvoices" runat="server" AutoGenerateColumns="false"
                        CssClass="dfm-table" GridLines="None" EmptyDataText="No invoices yet for this project.">
                        <Columns>
                            <asp:BoundField DataField="PetRefNo"      HeaderText="Request Ref" />
                            <asp:BoundField DataField="VendorName"    HeaderText="Vendor" />
                            <asp:BoundField DataField="InvoiceNo"     HeaderText="Invoice No" />
                            <asp:BoundField DataField="InvoiceAmount" HeaderText="Amount" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                            <asp:BoundField DataField="InvoiceStatus" HeaderText="Status" />
                            <asp:BoundField DataField="PaymentDate"   HeaderText="Payment Date" DataFormatString="{0:dd-MMM-yyyy}" />
                            <asp:TemplateField HeaderText="Action">
                                <ItemTemplate>
                                    <a href='<%# ResolveUrl("~/Forms/PetWorkflow.aspx") + "?embed=1&id=" + Eval("PetFormID") + "&tab=budget" %>' onclick="return petOpenWorkflowLink(this);" class="btn btn-xs btn-primary"><i class="bi bi-arrow-right-circle"></i> Open</a>
                                </ItemTemplate>
                            </asp:TemplateField>
                        </Columns>
                    </asp:GridView>
                </div>
            </div>
        </div>
    </div>
    </asp:Panel>

    <div class="modal fade workflow-frame-modal" id="petWorkflowFrameModal" tabindex="-1" role="dialog">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header" style="background:#2F5597;color:#fff;">
                    <button type="button" class="close" data-dismiss="modal" style="color:#fff;opacity:.8;">&times;</button>
                    <h4 class="modal-title"><i class="bi bi-file-earmark-text"></i> Spend Request</h4>
                </div>
                <div class="modal-body">
                    <iframe id="petWorkflowFrame" title="Spend Request"></iframe>
                </div>
            </div>
        </div>
    </div>

    <!-- Attachments + Submit -->
    <asp:Panel ID="pnlLines" runat="server" Visible="false">
    <!-- File Attachments (optional) -->
    <div class="card-panel panel-attachments" style="margin-top:14px;">
        <div class="card-panel-hdr"><i class="bi bi-paperclip"></i> File Attachments <small style="font-weight:400;">(optional)</small></div>
        <div class="card-panel-body">
            <% if (IsEditable) { %>
            <div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:8px;">
                <asp:FileUpload ID="fuAttachment" runat="server" style="max-width:400px;" />
                <asp:Button ID="btnUploadAttachment" runat="server" CssClass="btn btn-info btn-sm"
                    Text="Upload" OnClick="btnUploadAttachment_Click" CausesValidation="false" />
            </div>
            <% } %>
            <asp:Panel ID="pnlAttachments" runat="server">
                <asp:Repeater ID="rptAttachments" runat="server" OnItemCommand="rptAttachments_ItemCommand">
                    <ItemTemplate>
                        <div class="attach-item">
                            <i class="bi bi-file-earmark"></i>
                            <a href='<%# ResolveUrl("~/Forms/PetWorkflow.aspx?dl=" + Eval("AttachmentID")) %>' target="_blank"><%# Eval("FileName") %></a>
                            <small style="color:#64748b;"><%# Eval("UploadedAt", "{0:dd-MMM-yyyy}") %></small>
                            <% if (IsEditable) { %>
                            <asp:LinkButton runat="server" CssClass="btn btn-xs btn-danger"
                                CommandName="DelAttach" CommandArgument='<%# Eval("AttachmentID") %>'
                                OnClientClick="return confirm('Remove?');"><i class="bi bi-x"></i></asp:LinkButton>
                            <% } %>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </asp:Panel>
        </div>
    </div>

    <!-- Submit Spend Request -->
    <% if (IsEditable && CurrentPetFormId > 0) { %>
    <div style="margin-top:14px;padding:14px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">
        <strong>Ready to Submit?</strong>
        <% if (!string.IsNullOrEmpty(ApproverName)) { %>
        <p style="font-size:.85em;color:#64748b;margin:4px 0 10px;">
            Submitting will send the Spend Request
            <% if (!string.IsNullOrEmpty(ReviewerName)) { %>
                to reviewer <strong><%= Server.HtmlEncode(ReviewerName) %></strong>
            <% } else { %>
                directly to approver <strong><%= Server.HtmlEncode(ApproverName) %></strong>
            <% } %>
            for action.
        </p>
        <div class="comments-box" style="margin-bottom:8px;">
            <label>Comments</label>
            <asp:TextBox ID="txtSubmitComments" runat="server" CssClass="form-control" placeholder="Optional comments..." TextMode="MultiLine" Rows="2" style="margin-top:4px;" />
        </div>
        <asp:Button ID="btnSubmitPet" runat="server" CssClass="btn btn-warning" Text="Submit Spend Request for Approval"
            OnClick="btnSubmitPet_Click" OnClientClick="return confirm('Submit this Spend Request for approval?');" />
        <% } else { %>
        <p style="font-size:.85em;color:#92400e;margin:4px 0 0;background:#fef3c7;border:1px solid #fde68a;border-radius:6px;padding:8px 10px;">
            <i class="bi bi-info-circle"></i> No Approver is assigned, so this project is currently tracked as <strong>Draft</strong> only.
            Select an Approver above and click <strong>Save</strong> if you want to submit it for approval.
        </p>
        <% } %>
    </div>
    <% } %>
    </asp:Panel><!-- /pnlLines -->
</div><!-- /tabPet -->

<!-- ================================================================ TAB 2: PROJECT DETAILS ================================================================ -->
<div class="tab-pane <%= TabPane("project") %>" id="tabProject">
    <asp:Panel ID="pnlProjectDetails" runat="server" Visible="false">
    <div class="card-panel panel-spend-request">
        <div class="card-panel-hdr"><i class="bi bi-folder2-open"></i> JIRA / Project Information &mdash; <asp:Literal ID="litProjId" runat="server" /></div>
        <div class="card-panel-body">
            <div id="jiraFieldsGrid" class="p-3">
            <div class="table-responsive">
            <table class="table proj-detail-tbl mb-0">
                <tbody>
                    <%-- Row 1: Project Name | Project Type | Stage | RAG Status --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-folder2"></i>Project Name</td>
                        <td class="val"><asp:Literal ID="litJProjectName" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-lightning"></i>Project Type</td>
                        <td class="val"><asp:Literal ID="litJProjectType" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-graph-up"></i>Stage</td>
                        <td class="val"><asp:Literal ID="litJStage" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-circle-fill"></i>RAG Status</td>
                        <td class="val"><asp:Literal ID="litJRag" runat="server" /></td>
                    </tr>
                    <%-- Row 2: Demand Type | Department | Classification | Platform --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-tag"></i>Demand Type</td>
                        <td class="val"><asp:Literal ID="litJDemand" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-building"></i>Department</td>
                        <td class="val"><asp:Literal ID="litJDept" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-filter"></i>Classification</td>
                        <td class="val"><asp:Literal ID="litJClassification" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-cpu"></i>Platform</td>
                        <td class="val"><asp:Literal ID="litJPlatform" runat="server" /></td>
                    </tr>
                    <%-- Row 3: Platform Vertical | Issue Type | Manager | Tech Lead --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-layers"></i>Platform Vertical</td>
                        <td class="val"><asp:Literal ID="litJPlatformVertical" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-card-list"></i>Issue Type</td>
                        <td class="val"><asp:Literal ID="litJIssueType" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person-badge"></i>Manager</td>
                        <td class="val"><asp:Literal ID="litJMgr" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-tools"></i>Tech Lead</td>
                        <td class="val"><asp:Literal ID="litJTech" runat="server" /></td>
                    </tr>
                    <%-- Row 4: Sponsor | Stakeholder | Assignee | Reporter --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-star"></i>Sponsor</td>
                        <td class="val"><asp:Literal ID="litJSponsor" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-people"></i>Stakeholder</td>
                        <td class="val"><asp:Literal ID="litJStakeholder" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person"></i>Assignee</td>
                        <td class="val"><asp:Literal ID="litJAssignee" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person-lines-fill"></i>Reporter</td>
                        <td class="val"><asp:Literal ID="litJReporter" runat="server" /></td>
                    </tr>
                    <%-- Row 5: Accountable Exec Lead | SME Lead | Accountable Exec | IDH Portfolio Head --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-person-check"></i>Accountable Exec Lead</td>
                        <td class="val"><asp:Literal ID="litJAccExecLead" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person-workspace"></i>SME Lead</td>
                        <td class="val"><asp:Literal ID="litJSmeLead" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person-gear"></i>Accountable Exec</td>
                        <td class="val"><asp:Literal ID="litJAccExec" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-briefcase"></i>IDH Portfolio Head</td>
                        <td class="val"><asp:Literal ID="litJPortfolioHead" runat="server" /></td>
                    </tr>
                    <%-- Row 6: Assigned PM | Demand Owner | Chief | Primary Classification --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-person-vcard"></i>Assigned PM</td>
                        <td class="val"><asp:Literal ID="litJAssignedPM" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person-plus"></i>Demand Owner</td>
                        <td class="val"><asp:Literal ID="litJDemandOwner" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-award"></i>Chief</td>
                        <td class="val"><asp:Literal ID="litJChief" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-diagram-3"></i>Primary Classification</td>
                        <td class="val"><asp:Literal ID="litJPrimaryClass" runat="server" /></td>
                    </tr>
                    <%-- Row 7: JIRA Created | JIRA Updated | Start Date | End Date --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-calendar-plus"></i>JIRA Created</td>
                        <td class="val"><asp:Literal ID="litJCreated" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar-check"></i>JIRA Updated</td>
                        <td class="val"><asp:Literal ID="litJUpdated" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-play-circle"></i>Start Date</td>
                        <td class="val"><asp:Literal ID="litJStart" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-stop-circle"></i>End Date</td>
                        <td class="val"><asp:Literal ID="litJEnd" runat="server" /></td>
                    </tr>
                    <%-- Row 8 (NEW): Proj Performing Dept | Proj Sponsor Dept | Demand Dept | Requester Dept --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-building-check"></i>Proj Performing Dept</td>
                        <td class="val"><asp:Literal ID="litJProjPerformingDept" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-building-add"></i>Proj Sponsor Dept</td>
                        <td class="val"><asp:Literal ID="litJProjSponsorDept" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-buildings"></i>Demand Dept</td>
                        <td class="val"><asp:Literal ID="litJDemandDept" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-person-rolodex"></i>Requester Dept</td>
                        <td class="val"><asp:Literal ID="litJRequesterDept" runat="server" /></td>
                    </tr>
                    <%-- Row 9 (NEW): Project Dept | Demand Segment | Demand Title | Regulatory Observation --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-building-gear"></i>Project Dept</td>
                        <td class="val"><asp:Literal ID="litJProjectDept" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-pie-chart"></i>Demand Segment</td>
                        <td class="val"><asp:Literal ID="litJDemandSegment" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-card-heading"></i>Demand Title</td>
                        <td class="val"><asp:Literal ID="litJDemandTitle" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-shield-exclamation"></i>Regulatory Obs.</td>
                        <td class="val"><asp:Literal ID="litJRegulatoryObs" runat="server" /></td>
                    </tr>
                    <%-- Row 10 (NEW): Baseline Start | Baseline End | BL1 Actual Start | BL1 Actual End --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-calendar2-event"></i>Baseline Start</td>
                        <td class="val"><asp:Literal ID="litJBaselineStart" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar2-check"></i>Baseline End</td>
                        <td class="val"><asp:Literal ID="litJBaselineEnd" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar2-range"></i>BL1 Actual Start</td>
                        <td class="val"><asp:Literal ID="litJBl1ActualStart" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar2-x"></i>BL1 Actual End</td>
                        <td class="val"><asp:Literal ID="litJBl1ActualEnd" runat="server" /></td>
                    </tr>
                    <%-- Row 11 (NEW): BL0 Planned Start | BL0 Planned End | BL0 Actual Start | BL0 Actual End --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-calendar3-range"></i>BL0 Planned Start</td>
                        <td class="val"><asp:Literal ID="litJBl0PlannedStart" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar3-event"></i>BL0 Planned End</td>
                        <td class="val"><asp:Literal ID="litJBl0PlannedEnd" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar3"></i>BL0 Actual Start</td>
                        <td class="val"><asp:Literal ID="litJBl0ActualStart" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-calendar3-week"></i>BL0 Actual End</td>
                        <td class="val"><asp:Literal ID="litJBl0ActualEnd" runat="server" /></td>
                    </tr>
                    <%-- Row 12 (NEW): BL1 Actual Go Live | Rollout Status | Epic Status | BRD Status --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-rocket-takeoff"></i>BL1 Actual Go Live</td>
                        <td class="val"><asp:Literal ID="litJBl1ActualGoLive" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-broadcast"></i>Rollout Status</td>
                        <td class="val"><asp:Literal ID="litJRolloutStatus" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-lightning-charge"></i>Epic Status</td>
                        <td class="val"><asp:Literal ID="litJEpicStatus" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-file-earmark-text"></i>BRD Status</td>
                        <td class="val"><asp:Literal ID="litJBrdStatus" runat="server" /></td>
                    </tr>
                    <%-- Row 13 (NEW): Script Status | Status (Grey) | Status Reason | Initiative Status --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-code-square"></i>Script Status</td>
                        <td class="val"><asp:Literal ID="litJScriptStatus" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-circle"></i>Status (Grey)</td>
                        <td class="val"><asp:Literal ID="litJStatusGrey" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-chat-square-text"></i>Status Reason</td>
                        <td class="val"><asp:Literal ID="litJStatusReason" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-flag"></i>Initiative Status</td>
                        <td class="val"><asp:Literal ID="litJInitiativeStatus" runat="server" /></td>
                    </tr>
                    <%-- Row 14 (NEW): Project Overall Status | CBTP BRD Status | FSD Status | Project Size --%>
                    <tr>
                        <td class="lbl"><i class="bi bi-check2-all"></i>Project Overall Status</td>
                        <td class="val"><asp:Literal ID="litJProjectOverallStatus" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-journal-check"></i>CBTP BRD Status</td>
                        <td class="val"><asp:Literal ID="litJCbtpBrdStatus" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-file-earmark-check"></i>FSD Status</td>
                        <td class="val"><asp:Literal ID="litJFsdStatus" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-rulers"></i>Project Size</td>
                        <td class="val">
                            <a href="javascript:void(0)"
                               onclick="$('.pet-nav-tabs a[href=\"#tabSizing\"]').tab('show'); document.getElementById('<%= hfActiveTab.ClientID %>').value='sizing'; return false;"
                               title="Click to view Project Sizing tab" style="text-decoration:none;">
                                <asp:Literal ID="litProjectSize" runat="server" Text="<span class='label label-default' style=''>Not assessed</span>" />
                                <i class="bi bi-arrow-right-circle" style="margin-left:4px;opacity:.6;"></i>
                            </a>
                            <asp:HyperLink ID="hlProjectSize" runat="server" style="display:none;" />
                        </td>
                    </tr>
                </tbody>
            </table>
            </div>
        </div>
        </div>
    </div>

    <div class="card-panel panel-budget-line-items">
        <div class="card-panel-hdr"><i class="bi bi-currency-dollar"></i> CAPEX Amounts for this Project</div>
        <div class="card-panel-body" style="padding:0;overflow-x:auto;">
            <asp:GridView ID="gvCapexAmt" runat="server" AutoGenerateColumns="false" CssClass="dfm-table" GridLines="None" EmptyDataText="No CAPEX data.">
                <Columns>
                    <asp:BoundField DataField="ItemID"         HeaderText="CAPEX ID" />
                    <asp:BoundField DataField="ItemDescription" HeaderText="Description" />
                    <asp:BoundField DataField="BudgetedAmount"  HeaderText="Budget (AED)"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="UtilizedAmount"  HeaderText="Utilized (AED)"  DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="LockedAmount"    HeaderText="Locked (AED)"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="AvailableAmount" HeaderText="Available (AED)" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                </Columns>
            </asp:GridView>
        </div>
    </div>

    <div class="card-panel panel-budget-line-items">
        <div class="card-panel-hdr"><i class="bi bi-receipt"></i> OPEX Amounts for this Project</div>
        <div class="card-panel-body" style="padding:0;overflow-x:auto;">
            <asp:GridView ID="gvOpexAmt" runat="server" AutoGenerateColumns="false" CssClass="dfm-table" GridLines="None" EmptyDataText="No OPEX data.">
                <Columns>
                    <asp:BoundField DataField="ItemID"         HeaderText="OPEX ID" />
                    <asp:BoundField DataField="ItemDescription" HeaderText="Description" />
                    <asp:BoundField DataField="BudgetedAmount"  HeaderText="Budget (AED)"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="UtilizedAmount"  HeaderText="Utilized (AED)"  DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="LockedAmount"    HeaderText="Locked (AED)"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="AvailableAmount" HeaderText="Available (AED)" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                </Columns>
            </asp:GridView>
        </div>
    </div>

    <div class="card-panel panel-budget-line-items">
        <div class="card-panel-hdr"><i class="bi bi-journal-bookmark"></i> GL Amounts for this Project</div>
        <div class="card-panel-body" style="padding:0;overflow-x:auto;">
            <asp:GridView ID="gvGLAmt" runat="server" AutoGenerateColumns="false" CssClass="dfm-table" GridLines="None" EmptyDataText="No GL data.">
                <Columns>
                    <asp:BoundField DataField="GLNumber"        HeaderText="GL Number" />
                    <asp:BoundField DataField="GLDescription"   HeaderText="Description" />
                    <asp:BoundField DataField="BudgetedAmount"  HeaderText="Budget"     DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="BPMLockedAmount" HeaderText="BPM Lock"   DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="AMSLockedAmount" HeaderText="AMS Lock"   DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="UtilizedAmount"  HeaderText="Utilized"   DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="BalanceAmount"   HeaderText="Balance"    DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                </Columns>
            </asp:GridView>
        </div>
    </div>
    </asp:Panel>
    <asp:Panel ID="pnlNoProject" runat="server">
        <div class="alert alert-info"><asp:Literal ID="litNoProjectMsg" runat="server" Text="Select a JIRA ID / Project in the Request tab first." /></div>
    </asp:Panel>
</div><!-- /tabProject -->

<!-- ================================================================ TAB 3: PROJECT SIZING ================================================================ -->
<div class="tab-pane <%= TabPane("sizing") %>" id="tabSizing">
    <div>

        <% if (!string.IsNullOrEmpty(ddlProject.SelectedValue)) { %>

            <%-- Current result badge (populated server-side from DB) --%>
            <div style="margin-bottom:14px;">
                <asp:Literal ID="litSizingResultBadge" runat="server" />
            </div>
            <asp:Literal ID="litSizingSavedInfo" runat="server" />

    <div style="background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:12px 16px;margin-bottom:14px;font-size:.84em;color:#0c4a6e;">
        <strong>Scoring Guide:</strong> Select Low (1), Medium (3) or High (5) for each criterion.
        Weighted total &rarr; Size: <strong>XS</strong> (&le;1.5) | <strong>S</strong> (1.5&ndash;2.3) | <strong>M</strong> (2.3&ndash;3.2) | <strong>L</strong> (3.2&ndash;4.1) | <strong>XL</strong> (&gt;4.1)
    </div>
    <div class="ps-card">
        <div class="ps-card-title">1. Technical / Service Complexity <span class="label label-default" style="font-size:.7em;">Weight: 20%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q1" id="sz_q1_1" value="1" onchange="szScore()" /><label for="sz_q1_1" class="low">&#10003; Low (1)<br/><small>Existing platforms, proven tech</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q1" id="sz_q1_3" value="3" onchange="szScore()" /><label for="sz_q1_3" class="medium">&#9888; Medium (3)<br/><small>Some custom design, limited novelty</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q1" id="sz_q1_5" value="5" onchange="szScore()" /><label for="sz_q1_5" class="high">&#9940; High (5)<br/><small>New/unproven tech, complex integrations</small></label></div>
        </div>
    </div>
    <div class="ps-card">
        <div class="ps-card-title">2. Regulatory / Compliance / Security <span class="label label-default" style="font-size:.7em;">Weight: 20%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q2" id="sz_q2_1" value="1" onchange="szScore()" /><label for="sz_q2_1" class="low">&#10003; Low (1)<br/><small>No regulated data, standard security</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q2" id="sz_q2_3" value="3" onchange="szScore()" /><label for="sz_q2_3" class="medium">&#9888; Medium (3)<br/><small>Compliance / privacy requirements</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q2" id="sz_q2_5" value="5" onchange="szScore()" /><label for="sz_q2_5" class="high">&#9940; High (5)<br/><small>High regulatory/audit exposure</small></label></div>
        </div>
    </div>
    <div class="ps-card">
        <div class="ps-card-title">3. Stakeholder Complexity <span class="label label-default" style="font-size:.7em;">Weight: 15%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q3" id="sz_q3_1" value="1" onchange="szScore()" /><label for="sz_q3_1" class="low">&#10003; Low (1)<br/><small>Single business owner, aligned</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q3" id="sz_q3_3" value="3" onchange="szScore()" /><label for="sz_q3_3" class="medium">&#9888; Medium (3)<br/><small>Multiple BUs, competing priorities</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q3" id="sz_q3_5" value="5" onchange="szScore()" /><label for="sz_q3_5" class="high">&#9940; High (5)<br/><small>Many stakeholders, divergent interests</small></label></div>
        </div>
    </div>
    <div class="ps-card">
        <div class="ps-card-title">4. Resource / Capability Dependency <span class="label label-default" style="font-size:.7em;">Weight: 15%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q4" id="sz_q4_1" value="1" onchange="szScore()" /><label for="sz_q4_1" class="low">&#10003; Low (1)<br/><small>Skills available internally</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q4" id="sz_q4_3" value="3" onchange="szScore()" /><label for="sz_q4_3" class="medium">&#9888; Medium (3)<br/><small>Some external specialists</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q4" id="sz_q4_5" value="5" onchange="szScore()" /><label for="sz_q4_5" class="high">&#9940; High (5)<br/><small>Critical niche skills, major hiring</small></label></div>
        </div>
    </div>
    <div class="ps-card">
        <div class="ps-card-title">5. Scale / Reliability / Performance <span class="label label-default" style="font-size:.7em;">Weight: 15%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q5" id="sz_q5_1" value="1" onchange="szScore()" /><label for="sz_q5_1" class="low">&#10003; Low (1)<br/><small>Non-critical, degradation acceptable</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q5" id="sz_q5_3" value="3" onchange="szScore()" /><label for="sz_q5_3" class="medium">&#9888; Medium (3)<br/><small>Normal production SLAs</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q5" id="sz_q5_5" value="5" onchange="szScore()" /><label for="sz_q5_5" class="high">&#9940; High (5)<br/><small>Mission-critical, strict HA/SLA</small></label></div>
        </div>
    </div>
    <div class="ps-card">
        <div class="ps-card-title">6. Interdependencies / Portfolio <span class="label label-default" style="font-size:.7em;">Weight: 10%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q6" id="sz_q6_1" value="1" onchange="szScore()" /><label for="sz_q6_1" class="low">&#10003; Low (1)<br/><small>Standalone, few dependencies</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q6" id="sz_q6_3" value="3" onchange="szScore()" /><label for="sz_q6_3" class="medium">&#9888; Medium (3)<br/><small>Some upstream/downstream deps</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q6" id="sz_q6_5" value="5" onchange="szScore()" /><label for="sz_q6_5" class="high">&#9940; High (5)<br/><small>Foundational, impacts many initiatives</small></label></div>
        </div>
    </div>
    <div class="ps-card">
        <div class="ps-card-title">7. Budget / Contract Complexity <span class="label label-default" style="font-size:.7em;">Weight: 5%</span></div>
        <div class="ps-radio-group">
            <div class="ps-radio-btn"><input type="radio" name="sz_q7" id="sz_q7_1" value="1" onchange="szScore()" /><label for="sz_q7_1" class="low">&#10003; Low (1)<br/><small>Small budget, simple procurement</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q7" id="sz_q7_3" value="3" onchange="szScore()" /><label for="sz_q7_3" class="medium">&#9888; Medium (3)<br/><small>Multi-phase funding, complex terms</small></label></div>
            <div class="ps-radio-btn"><input type="radio" name="sz_q7" id="sz_q7_5" value="5" onchange="szScore()" /><label for="sz_q7_5" class="high">&#9940; High (5)<br/><small>Large capital, strategic supplier</small></label></div>
        </div>
    </div>
    <div id="szLiveResult" class="ps-result-panel">
        <div class="ps-result-badge" id="szLiveBadge">--</div>
        <div id="szLiveLabel" style="font-size:1em;font-weight:600;margin-bottom:6px;"></div>
        <div class="ps-score-bar"><div class="ps-score-fill" id="szScoreFill" style="width:0%;background:#facc15;"></div></div>
        <div style="font-size:.8em;opacity:.8;" id="szScoreText">Select all 7 criteria to see score</div>
    </div>


            <%-- Hidden fields carry questionnaire data to server on save --%>
            <input type="hidden" id="sz_hfQ1" name="sz_hfQ1" /><input type="hidden" id="sz_hfQ2" name="sz_hfQ2" />
            <input type="hidden" id="sz_hfQ3" name="sz_hfQ3" /><input type="hidden" id="sz_hfQ4" name="sz_hfQ4" />
            <input type="hidden" id="sz_hfQ5" name="sz_hfQ5" /><input type="hidden" id="sz_hfQ6" name="sz_hfQ6" />
            <input type="hidden" id="sz_hfQ7" name="sz_hfQ7" />
            <input type="hidden" id="sz_hfC1" name="sz_hfC1" /><input type="hidden" id="sz_hfC2" name="sz_hfC2" />
            <input type="hidden" id="sz_hfC3" name="sz_hfC3" /><input type="hidden" id="sz_hfC4" name="sz_hfC4" />
            <input type="hidden" id="sz_hfC5" name="sz_hfC5" /><input type="hidden" id="sz_hfC6" name="sz_hfC6" />
            <input type="hidden" id="sz_hfC7" name="sz_hfC7" />

            <%-- Action buttons --%>
            <div style="margin-top:16px;display:flex;gap:10px;flex-wrap:wrap;align-items:center;">
                <asp:Button ID="btnSizingSave" runat="server" Text="Save Assessment"
                    CssClass="btn btn-primary" OnClientClick="return szPreSave();"
                    OnClick="btnSizingSave_Click" CausesValidation="false" />
                <button type="button" class="btn btn-default" onclick="szClear(); return false;">
                    <i class="bi bi-arrow-clockwise"></i> Reset
                </button>
            </div>

            <%-- Score breakdown table (client-side) --%>
            <div id="szBreakdownDiv" style="margin-top:20px;display:none;">
                <h5 style="font-weight:700;color:#1e3a5f;">Score Breakdown</h5>
                <table class="table table-bordered table-condensed ps-breakdown">
                    <thead><tr><th>Criterion</th><th>Rationale</th><th style="text-align:center;">Score</th><th style="text-align:center;">Weight</th><th style="text-align:center;">Weighted</th></tr></thead>
                    <tbody id="szBreakdownBody"></tbody>
                    <tfoot><tr style="font-weight:700;background:#f8fafc;"><td colspan="4" style="text-align:right;">Total Weighted Score</td><td style="text-align:center;" id="szBreakdownTotal">--</td></tr></tfoot>
                </table>
            </div>

            <% } else { %>
            <div class="alert alert-info" style="margin:16px 0;">
                <i class="bi bi-info-circle"></i>
                Please select a JIRA ID in the <strong>Registration</strong> tab to access Project Sizing.
            </div>
            <% } %>
        </div>

</div><!-- /tabSizing -->

<!-- ================================================================ TAB 4: PET APPROVAL ================================================================ -->
<div class="tab-pane <%= TabPane("approval") %>" id="tabApproval">
    <asp:Panel ID="pnlApprovalDetails" runat="server">
    <div class="kpi-row">
        <div class="kpi-card kpi-blue"><span class="kpi-icon"><i class="bi bi-person"></i></span>
            <div><div class="kpi-label">Requestor</div><div class="kpi-val"><asp:Literal ID="litApprRequestor" runat="server" Text="-" /></div></div></div>
        <div class="kpi-card kpi-orange"><span class="kpi-icon"><i class="bi bi-person-check"></i></span>
            <div><div class="kpi-label">Reviewer</div><div class="kpi-val"><asp:Literal ID="litApprReviewer" runat="server" Text="-" /></div></div></div>
        <div class="kpi-card kpi-green"><span class="kpi-icon"><i class="bi bi-check2-circle"></i></span>
            <div><div class="kpi-label">Approver</div><div class="kpi-val"><asp:Literal ID="litApprApprover" runat="server" Text="-" /></div></div></div>
        <div class="kpi-card kpi-red"><span class="kpi-icon"><i class="bi bi-flag"></i></span>
            <div><div class="kpi-label">Current Status</div><div class="kpi-val"><asp:Literal ID="litApprStatus" runat="server" Text="-" /></div></div></div>
    </div>
    <!-- Budget Source summary -->
    <asp:Literal ID="litApprBudgetInfo" runat="server" />

    <!-- Budget impact if approved (for approver's reference) -->
    <asp:Panel ID="pnlApproverImpact" runat="server" Visible="false">
    <div class="approver-impact">
        <strong><i class="bi bi-graph-up-arrow"></i> Budget Impact if Approved</strong>
        <div class="budget-panel-row" style="margin-top:8px;">
            <div class="bgt-budget">  <div class="budget-label">Request Total (AED)</div>   <div class="budget-val"><asp:Literal ID="litImpactRequested"     runat="server" Text="0" /></div></div>
            <div class="bgt-utilized"><div class="budget-label">Current Utilized</div>  <div class="budget-val"><asp:Literal ID="litImpactCurrentUtil"   runat="server" Text="0" /></div></div>
            <div class="bgt-locked">  <div class="budget-label">Current Locked</div>   <div class="budget-val"><asp:Literal ID="litImpactCurrentLocked" runat="server" Text="0" /></div></div>
            <div class="bgt-avail">   <div class="budget-label">Available Now</div>     <div class="budget-val"><asp:Literal ID="litImpactAvail"         runat="server" Text="0" /></div></div>
            <div class="bgt-net">     <div class="budget-label">Balance After</div>     <div class="budget-val"><asp:Literal ID="litImpactAfter"         runat="server" Text="0" /></div></div>
        </div>
    </div>
    </asp:Panel>

    <!-- Decision panel (shown to reviewer/approver) -->
    <asp:Panel ID="pnlDecision" runat="server" Visible="false">
    <div class="decision-panel" style="margin-top:12px;">
        <h4 style="margin:0 0 10px;color:#1a3c5e;"><i class="bi bi-check2-square"></i>
            <asp:Literal ID="litDecisionTitle" runat="server" Text="Your Decision" />
        </h4>
        <div class="form-group comments-box">
            <label>Comments</label>
            <asp:TextBox ID="txtDecisionComments" runat="server" CssClass="form-control" TextMode="MultiLine" Rows="3" placeholder="Enter your comments..." />
        </div>
        <div class="decision-btns">
            <asp:Button ID="btnApprove"  runat="server" CssClass="btn btn-success btn-lg" Text="Approve"   OnClick="btnApprove_Click"  OnClientClick="return confirm('Approve this Spend Request?');" />
            <asp:Button ID="btnReject"   runat="server" CssClass="btn btn-danger btn-lg"  Text="Reject"    OnClick="btnReject_Click"   OnClientClick="return confirm('Reject this Spend Request?');" />
            <asp:Button ID="btnSendBack" runat="server" CssClass="btn btn-warning btn-lg" Text="Send Back" OnClick="btnSendBack_Click" OnClientClick="return confirm('Send back to requestor?');" />
        </div>
    </div>
    </asp:Panel>

    <div class="card-panel panel-approval-history" style="margin-top:14px;">
        <div class="card-panel-hdr"><i class="bi bi-clock-history"></i> Workflow History</div>
        <div class="card-panel-body" style="padding:0;overflow-x:auto;">
            <asp:GridView ID="gvHistory" runat="server" AutoGenerateColumns="false" CssClass="dfm-table" GridLines="None" EmptyDataText="No history.">
                <Columns>
                    <asp:BoundField DataField="ActionDate"  HeaderText="Date"       DataFormatString="{0:dd-MMM-yyyy HH:mm}" />
                    <asp:BoundField DataField="Action"      HeaderText="Action" />
                    <asp:BoundField DataField="ActionBy"    HeaderText="By" />
                    <asp:BoundField DataField="FromStatus"  HeaderText="From" />
                    <asp:BoundField DataField="ToStatus"    HeaderText="To" />
                    <asp:BoundField DataField="Comments"    HeaderText="Comments" />
                </Columns>
            </asp:GridView>
        </div>
    </div>
    </asp:Panel>
</div><!-- /tabApproval -->

<!-- ================================================================ TAB 5: CSV IMPORT ================================================================ -->
<div class="tab-pane <%= TabPane("import") %>" id="tabImport">
    <div class="card-panel panel-spend-request">
        <div class="card-panel-hdr"><i class="bi bi-file-earmark-arrow-up"></i> Import PET Lines from CSV</div>
        <div class="card-panel-body">
            <% if (!IsEditable && CurrentPetFormId > 0) { %>
            <div class="alert alert-warning" style="font-size:.88em;">
                <i class="bi bi-lock-fill"></i> <strong>Locked:</strong> CSV import is disabled while the Spend Request is in <strong><%= CurrentStatus %></strong> state.
                <% if (CurrentStatus == "Approved") { %> Approved PETs cannot be amended.<% } %>
                <% if (CurrentStatus == "PendingReview" || CurrentStatus == "PendingApproval") { %> Amendments are not allowed during approval. Wait for the outcome.<% } %>
            </div>
            <% } else { %>
            <div class="alert alert-info" style="font-size:.85em;">
                <strong>Expected format (PET Form.csv):</strong><br/>
                <code>Department, ID, Exp. Head, Topic, Vendor, Description, Cost Type, Unit Type, Unit(s), Unit Price, Base CY, Amt. FCY, Amt. LCY, Cont. %, Final Amt LCY, Yearly Recurrence</code><br/>
                Rows with all-blank amount fields will be skipped. Header row is auto-detected.
            </div>
            <div class="row">
                <div class="col-md-6">
                    <label class="control-label">Select CSV File</label>
                    <asp:FileUpload ID="fuPetCsv" runat="server" CssClass="form-control" accept=".csv" />
                </div>
                <div class="col-md-6" style="padding-top:25px;">
                    <asp:Button ID="btnImportPetCsv" runat="server" Text="Import Lines"
                        CssClass="btn btn-primary" OnClick="btnImportPetCsv_Click" CausesValidation="false" />
                    <asp:Button ID="btnDownloadTemplate" runat="server" Text="Download Template"
                        CssClass="btn btn-default" OnClick="btnDownloadTemplate_Click" CausesValidation="false" />
                </div>
            </div>
            <% } %>
            <asp:Label ID="lblImportStatus" runat="server" CssClass="label label-info" style="margin-top:10px;display:block;font-size:.9em;" />

            <asp:Panel ID="pnlImportPreview" runat="server" Visible="false" style="margin-top:16px;">
                <div style="font-weight:700;color:#1a3c5e;margin-bottom:6px;">Preview — imported lines:</div>
                <div class="table-responsive">
                <asp:GridView ID="gvImportPreview" runat="server" CssClass="table table-bordered table-sm"
                    AutoGenerateColumns="true" AllowPaging="false" />
                </div>
            </asp:Panel>
        </div>
    </div>

    <% if (ShowBudgetTab) { %>
    <div class="card-panel panel-budget-line-items">
        <div class="card-panel-hdr"><i class="bi bi-file-earmark-arrow-up"></i> Import Budget Lines from CSV</div>
        <div class="card-panel-body">
            <% if (!CanManageBudget) { %>
            <div class="alert alert-warning" style="font-size:.88em;">
                <i class="bi bi-lock-fill"></i> <strong>Locked:</strong> <%= Server.HtmlEncode(BudgetReadOnlyReason) %>
            </div>
            <% } else { %>
            <div class="alert alert-info" style="font-size:.85em;">
                <strong>Expected format:</strong><br/>
                <code>Vendor, Justification, Cost, Currency, GL, Request Ref, CAM ID, CAM Status, CAM Comments, LPO Request, LPO Status, LPO Comments</code><br/>
                Header row is auto-detected.
            </div>
            <div class="row">
                <div class="col-md-6">
                    <label class="control-label">Select CSV File</label>
                    <asp:FileUpload ID="fuBudgetCsv" runat="server" CssClass="form-control" accept=".csv" />
                </div>
                <div class="col-md-6" style="padding-top:25px;">
                    <asp:Button ID="btnImportBudgetCsv" runat="server" Text="Import Rows"
                        CssClass="btn btn-primary" OnClick="btnImportBudgetCsv_Click" CausesValidation="false" />
                    <asp:Button ID="btnDownloadBudgetTemplate" runat="server" Text="Download Template"
                        CssClass="btn btn-default" OnClick="btnDownloadBudgetTemplate_Click" CausesValidation="false" />
                </div>
            </div>
            <% } %>
            <asp:Label ID="lblBudgetImportStatus" runat="server" CssClass="label label-info" style="margin-top:10px;display:block;font-size:.9em;" />
            <asp:Panel ID="pnlBudgetImportPreview" runat="server" Visible="false" style="margin-top:16px;">
                <div style="font-weight:700;color:#1a3c5e;margin-bottom:6px;">Preview — imported rows:</div>
                <div class="table-responsive">
                <asp:GridView ID="gvBudgetImportPreview" runat="server" CssClass="table table-bordered table-sm"
                    AutoGenerateColumns="true" AllowPaging="false" />
                </div>
            </asp:Panel>
        </div>
    </div>
    <% } %>
</div><!-- /tabImport -->

<!-- ================================================================ TAB 6: BUDGET / INVOICE ================================================================ -->
<% if (ShowBudgetTab) { %>
<div class="tab-pane <%= TabPane("budget") %>" id="tabBudget">

    <% if (!string.IsNullOrEmpty(BudgetReadOnlyReason)) { %>
    <div class="alert alert-warning" style="font-size:.88em;">
        <i class="bi bi-lock-fill"></i> <strong>Read-only:</strong> <%= Server.HtmlEncode(BudgetReadOnlyReason) %>
    </div>
    <% } %>

    <div class="card-panel panel-budget-line-items">
        <div class="card-panel-hdr">
            <i class="bi bi-cash-coin"></i> Budget Lines
            <div style="margin-left:auto;display:flex;gap:6px;flex-wrap:wrap;">
            <% if (CanManageBudget) { %>
            <asp:LinkButton ID="btnAddBudgetLine" runat="server" CssClass="btn btn-xs btn-success"
                OnClick="btnAddBudgetLine_Click" CausesValidation="false"><i class="bi bi-plus-circle"></i> Add Budget Row</asp:LinkButton>
            <% } %>
            <asp:LinkButton ID="btnExportBudgetLines" runat="server" CssClass="btn btn-xs btn-default"
                OnClick="btnExportBudgetLines_Click" CausesValidation="false"><i class="bi bi-download"></i> Export CSV</asp:LinkButton>
            <asp:LinkButton ID="btnExportInvoices" runat="server" CssClass="btn btn-xs btn-default"
                OnClick="btnExportInvoices_Click" CausesValidation="false"><i class="bi bi-receipt"></i> Export Invoices CSV</asp:LinkButton>
            </div>
        </div>
        <div class="card-panel-body" style="padding:0;overflow-x:auto;">
            <asp:GridView ID="gvBudgetLines" runat="server" AutoGenerateColumns="false"
                CssClass="dfm-table pet-line-tbl" GridLines="None" DataKeyNames="BudgetLineID"
                OnRowCommand="gvBudgetLines_RowCommand"
                OnRowEditing="gvBudgetLines_RowEditing" OnRowUpdating="gvBudgetLines_RowUpdating" OnRowCancelingEdit="gvBudgetLines_RowCancelingEdit"
                EmptyDataText="No budget line items yet. Click 'Add Budget Row' or upload a CSV (in the CSV Import tab) to start.">
                <Columns>
                    <asp:BoundField DataField="SerialNo" HeaderText="#" ItemStyle-Width="30px" />
                    <asp:TemplateField HeaderText="Vendor">
                        <ItemTemplate><%# Eval("VendorName") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtEVendor" Text='<%# Eval("VendorName") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Justification">
                        <ItemTemplate><%# Eval("Justification") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtEJustification" Text='<%# Eval("Justification") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Cost" ItemStyle-CssClass="text-right">
                        <ItemTemplate><%# Eval("Cost", "{0:N2}") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtECost" Text='<%# Eval("Cost", "{0:N2}") %>' CssClass="form-control input-sm text-right" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="CCY">
                        <ItemTemplate><%# Eval("Currency") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtECcy" Text='<%# Eval("Currency") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="GL">
                        <ItemTemplate><%# Eval("GLNumber") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtEGL" Text='<%# Eval("GLNumber") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="PET Ref">
                        <ItemTemplate><%# Eval("PetRef") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtEPetRef" Text='<%# Eval("PetRef") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="CAM ID">
                        <ItemTemplate><%# Eval("CamId") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtECamId" Text='<%# Eval("CamId") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="CAM Status">
                        <ItemTemplate><%# Eval("CamStatus") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtECamStatus" Text='<%# Eval("CamStatus") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="CAM Comments">
                        <ItemTemplate><%# Eval("CamComments") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtECamComments" Text='<%# Eval("CamComments") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="LPO Request">
                        <ItemTemplate><%# Eval("LpoRequest") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtELpoRequest" Text='<%# Eval("LpoRequest") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="LPO Status">
                        <ItemTemplate><%# Eval("LpoStatus") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtELpoStatus" Text='<%# Eval("LpoStatus") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="LPO Comments">
                        <ItemTemplate><%# Eval("LpoComments") %></ItemTemplate>
                        <EditItemTemplate><asp:TextBox runat="server" ID="txtELpoComments" Text='<%# Eval("LpoComments") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Invoices" ItemStyle-CssClass="text-right">
                        <ItemTemplate>
                            <asp:LinkButton runat="server" CssClass="btn btn-xs btn-info" CommandName="ManageInvoices" CommandArgument='<%# Eval("BudgetLineID") %>'><%# Eval("InvoiceCount") %> (<%# string.Format("{0:N0}", Eval("InvoiceTotal")) %>)</asp:LinkButton>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Action" ItemStyle-CssClass="action-cell">
                        <ItemTemplate>
                            <% if (CanManageBudget) { %>
                            <div class="gv-acts">
                                <asp:LinkButton runat="server" CssClass="btn btn-xs btn-default" CommandName="Edit" ToolTip="Grid edit (Excel view)"><i class="bi bi-table"></i></asp:LinkButton>
                                <asp:LinkButton runat="server" CssClass="btn btn-xs btn-primary" CommandName="PopupEdit" CommandArgument='<%# Eval("BudgetLineID") %>' ToolTip="Edit via popup"><i class="bi bi-pencil"></i></asp:LinkButton>
                                <asp:LinkButton runat="server" CssClass="btn btn-xs btn-danger" CommandName="DelBudget" CommandArgument='<%# Eval("BudgetLineID") %>' OnClientClick="return confirm('Delete this budget line (and its invoices)?')" ToolTip="Delete"><i class="bi bi-trash"></i></asp:LinkButton>
                            </div>
                            <% } %>
                        </ItemTemplate>
                        <EditItemTemplate>
                            <div class="gv-acts">
                                <asp:LinkButton runat="server" CssClass="btn btn-xs btn-success" CommandName="Update" ToolTip="Save"><i class="bi bi-check-lg"></i></asp:LinkButton>
                                <asp:LinkButton runat="server" CssClass="btn btn-xs btn-default" CommandName="Cancel" ToolTip="Cancel"><i class="bi bi-x-lg"></i></asp:LinkButton>
                            </div>
                        </EditItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>
            <div class="total-bar">
                <span>Budget Lines: <strong><asp:Literal ID="litBudgetLineCount" runat="server" Text="0" /></strong></span>
                <span>Total Cost: <strong><asp:Literal ID="litBudgetTotalCost" runat="server" Text="0.00" /></strong></span>
                <span>Total Invoiced: <strong><asp:Literal ID="litBudgetTotalInvoiced" runat="server" Text="0.00" /></strong></span>
            </div>
        </div>
    </div>

    <div class="card-panel panel-budget-invoice" style="margin-top:14px;">
        <div class="card-panel-hdr"><i class="bi bi-receipt"></i> Invoices</div>
        <div class="card-panel-body" style="padding:0;overflow-x:auto;">
            <asp:GridView ID="gvAllInvoices" runat="server" AutoGenerateColumns="false"
                CssClass="dfm-table pet-line-tbl" GridLines="None"
                OnRowCommand="gvAllInvoices_RowCommand"
                EmptyDataText="No invoices added yet. Click the Invoices link on a Budget Line above to add one.">
                <Columns>
                    <asp:BoundField DataField="SerialNo"      HeaderText="Row #" ItemStyle-Width="45px" />
                    <asp:BoundField DataField="VendorName"    HeaderText="Vendor Name" />
                    <asp:BoundField DataField="Justification" HeaderText="Justification" />
                    <asp:BoundField DataField="GLNumber"      HeaderText="GL Number" />
                    <asp:BoundField DataField="InvoiceID"     HeaderText="Invoice ID" ItemStyle-Width="70px" />
                    <asp:BoundField DataField="InvoiceNo"     HeaderText="Invoice Number" />
                    <asp:BoundField DataField="InvoiceAmount" HeaderText="Invoice Amount" DataFormatString="{0:N2}" ItemStyle-CssClass="text-right" />
                    <asp:BoundField DataField="InvoiceStatus" HeaderText="Invoice Status" />
                    <asp:BoundField DataField="PaymentDate"   HeaderText="Payment Date" DataFormatString="{0:dd-MMM-yyyy}" />
                    <asp:TemplateField HeaderText="Action">
                        <ItemTemplate>
                            <asp:LinkButton runat="server" CssClass="btn btn-xs btn-primary" CommandName="ManageInvoices"
                                CommandArgument='<%# Eval("BudgetLineID") %>' ToolTip="Open Invoices popup for this Budget Line"><i class="bi bi-pencil"></i> Edit</asp:LinkButton>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>
        </div>
    </div>
</div><!-- /tabBudget -->
<% } %>

</div><!-- /tab-content -->

<script>
window.addEventListener('load', function() {
    // Currency auto-calc
    var rates = <%= CurrencyRatesJson %>;
    function calcAmts() {
        var uEl = document.getElementById('<%= txtLineUnits.ClientID %>');
        var pEl = document.getElementById('<%= txtLineUnitPrice.ClientID %>');
        var cEl = document.getElementById('<%= ddlLineCcy.ClientID %>');
        var fEl = document.getElementById('<%= txtLineAmtFCY.ClientID %>');
        var lEl = document.getElementById('<%= txtLineAmtLCY.ClientID %>');
        if (!uEl || !pEl) return;
        var fcy = (parseFloat(uEl.value) || 0) * (parseFloat(pEl.value) || 0);
        var ccy = cEl ? cEl.value : 'AED';
        var lcy = fcy * (rates[ccy] || 1);
        if (fEl) fEl.value = fcy.toFixed(2);
        if (lEl) lEl.value = lcy.toFixed(2);
    }
    ['<%= txtLineUnits.ClientID %>','<%= txtLineUnitPrice.ClientID %>'].forEach(function(id) {
        var el = document.getElementById(id); if (el) el.addEventListener('input', calcAmts);
    });
    var cEl = document.getElementById('<%= ddlLineCcy.ClientID %>');
    if (cEl) cEl.addEventListener('change', calcAmts);

    // Track active tab so postbacks restore the correct tab
    (function () {
        function getTabName(href) { return (href || '').replace('#tab', '').toLowerCase(); }
        var hfTab = document.getElementById('<%= hfActiveTab.ClientID %>');
        if (!hfTab) return;
        var links = document.querySelectorAll('.pet-nav-tabs a[data-toggle="tab"]');
        for (var i = 0; i < links.length; i++) {
            links[i].addEventListener('shown.bs.tab', function (e) {
                hfTab.value = getTabName(e.target.getAttribute('href'));
            });
            // Bootstrap 3 fires 'shown.bs.tab' but let's also handle plain click for safety
            links[i].addEventListener('click', function (e) {
                hfTab.value = getTabName(this.getAttribute('href'));
            });
        }
        // On load restore tab from hidden field
        var saved = hfTab.value;
        if (saved && saved !== 'pet') {
            var target = document.querySelector('.pet-nav-tabs a[href="#tab' + saved.charAt(0).toUpperCase() + saved.slice(1) + '"]');
            if (target && typeof jQuery !== 'undefined') { jQuery(target).tab('show'); }
        }
    }());

    // Select2 on all elements marked
    if (typeof jQuery !== 'undefined' && jQuery.fn && jQuery.fn.select2) {
        jQuery('.select2-enable').select2({ width: '100%' });
    }

    <% if (HostCloseOnInnerModalClose) { %>
    if (typeof jQuery !== 'undefined') {
        jQuery('#budgetLineModal,#invoiceModal').on('hidden.bs.modal', function () {
            try {
                if (window.parent && window.parent !== window && window.parent.prCloseDetailFrame) {
                    window.parent.prCloseDetailFrame();
                }
                else if (window.parent && window.parent !== window && window.parent.jQuery) {
                    window.parent.jQuery('#projectSpendRequestModal').modal('hide');
                }
            } catch (e) { }
        });
    }
    <% } %>
});

// Project Sizing: pre-save — copies radio values to hidden fields for server read
function szPreSave() {
    var allSet = true;
    for (var q = 1; q <= 7; q++) {
        var radios = document.getElementsByName('sz_q' + q);
        var val = 0;
        for (var i = 0; i < radios.length; i++) { if (radios[i].checked) { val = parseFloat(radios[i].value); break; } }
        if (!val) { allSet = false; break; }
        var hf = document.getElementById('sz_hfQ' + q);
        if (hf) hf.value = val;
    }
    if (!allSet) { alert('Please select a rating (Low / Medium / High) for all 7 criteria before saving.'); return false; }
    return true;
}

// Project Sizing: clear all selections
function szClear() {
    for (var q = 1; q <= 7; q++) {
        var radios = document.getElementsByName('sz_q' + q);
        for (var i = 0; i < radios.length; i++) radios[i].checked = false;
        var hf = document.getElementById('sz_hfQ' + q); if (hf) hf.value = '';
    }
    var res = document.getElementById('szLiveResult');
    if (res) { res.className = 'ps-result-panel'; }
    var bd = document.getElementById('szBreakdownDiv');
    if (bd) bd.style.display = 'none';
}

function petOpenWorkflowLink(link) {
    var frame = document.getElementById('petWorkflowFrame');
    if (!frame || typeof jQuery === 'undefined') return true;
    frame.src = link.href;
    jQuery('#petWorkflowFrameModal').modal('show');
    return false;
}

if (typeof jQuery !== 'undefined') {
    jQuery('#petWorkflowFrameModal').on('hidden.bs.modal', function () {
        document.getElementById('petWorkflowFrame').src = 'about:blank';
    });
}

// Project Sizing live score
var szWeights = [0.20, 0.20, 0.15, 0.15, 0.15, 0.10, 0.05];
function szScore() {
    var total = 0; var allSet = true;
    for (var q = 1; q <= 7; q++) {
        var radios = document.getElementsByName('sz_q' + q);
        var val = 0;
        for (var i = 0; i < radios.length; i++) { if (radios[i].checked) { val = parseFloat(radios[i].value); break; } }
        if (!val) allSet = false;
        total += val * szWeights[q - 1];
    }
    var res = document.getElementById('szLiveResult');
    var badge = document.getElementById('szLiveBadge');
    var lbl   = document.getElementById('szLiveLabel');
    var fill  = document.getElementById('szScoreFill');
    var txt   = document.getElementById('szScoreText');
    if (!res) return;
    res.className = 'ps-result-panel visible';
    txt.textContent = 'Total Weighted Score: ' + total.toFixed(2) + (allSet ? '' : ' (incomplete)');
    fill.style.width = Math.min(100, Math.max(0, ((total - 1) / 4) * 100)) + '%';
    var size, cls, color;
    if (total <= 1.5)      { size='XS'; cls='ps-result-xs'; color='#22c55e'; }
    else if (total <= 2.3) { size='S';  cls='ps-result-s';  color='#4ade80'; }
    else if (total <= 3.2) { size='M';  cls='ps-result-m';  color='#facc15'; }
    else if (total <= 4.1) { size='L';  cls='ps-result-l';  color='#fb923c'; }
    else                   { size='XL'; cls='ps-result-xl'; color='#f87171'; }
    badge.textContent = size;
    lbl.textContent   = 'Project Size: ' + size;
    fill.style.background = color;
    res.className = 'ps-result-panel visible ' + cls;
}
</script>

<% if (ShowBudgetTab) { %>
<!-- Budget Line Add/Edit Modal -->
<div class="modal fade" id="budgetLineModal" tabindex="-1" role="dialog" aria-labelledby="budgetLineModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header" style="background:#548235;color:#fff;">
                <button type="button" class="close" data-dismiss="modal" style="color:#fff;opacity:.8;">&times;</button>
                <h4 class="modal-title" id="budgetLineModalLabel">
                    <i class="bi bi-cash-coin"></i>
                    <asp:Literal ID="litBudgetModalTitle" runat="server" Text="New Budget Row" />
                </h4>
            </div>
            <div class="modal-body" style="padding:16px;">
                <asp:HiddenField ID="hfEditBudgetLineId" runat="server" Value="" />
                <div class="form-grid-4">
                    <div class="form-group">
                        <label>Vendor</label>
                        <asp:TextBox ID="txtBgtVendor" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group col-span-2">
                        <label>Justification</label>
                        <asp:TextBox ID="txtBgtJustification" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>Cost</label>
                        <asp:TextBox ID="txtBgtCost" runat="server" CssClass="form-control" Text="0" />
                    </div>
                    <div class="form-group">
                        <label>Currency</label>
                        <asp:DropDownList ID="ddlBgtCcy" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>GL Number</label>
                        <asp:TextBox ID="txtBgtGL" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>Request Ref</label>
                        <asp:TextBox ID="txtBgtPetRef" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>CAM ID</label>
                        <asp:TextBox ID="txtBgtCamId" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>CAM Status</label>
                        <asp:TextBox ID="txtBgtCamStatus" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group col-span-2">
                        <label>CAM Comments</label>
                        <asp:TextBox ID="txtBgtCamComments" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>LPO Request</label>
                        <asp:TextBox ID="txtBgtLpoRequest" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group">
                        <label>LPO Status</label>
                        <asp:TextBox ID="txtBgtLpoStatus" runat="server" CssClass="form-control" />
                    </div>
                    <div class="form-group col-span-2">
                        <label>LPO Comments</label>
                        <asp:TextBox ID="txtBgtLpoComments" runat="server" CssClass="form-control" />
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <asp:Button ID="btnSaveBudgetLine" runat="server" CssClass="btn btn-success" Text="Save"
                    OnClick="btnSaveBudgetLine_Click" CausesValidation="false" />
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>
            </div>
        </div>
    </div>
</div>

<!-- Invoice Management Modal (multiple invoices per Budget Line) -->
<div class="modal fade" id="invoiceModal" tabindex="-1" role="dialog" aria-labelledby="invoiceModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header" style="background:#C55A11;color:#fff;">
                <button type="button" class="close" data-dismiss="modal" style="color:#fff;opacity:.8;">&times;</button>
                <h4 class="modal-title" id="invoiceModalLabel">
                    <i class="bi bi-receipt"></i> Invoices
                </h4>
            </div>
            <div class="modal-body" style="padding:16px;">
                <asp:HiddenField ID="hfActiveBudgetLineId" runat="server" Value="0" />
                <table class="jira-detail-tbl" style="width:100%;margin-bottom:14px;">
                    <tr>
                        <td class="lbl"><i class="bi bi-building"></i>Vendor Name</td>
                        <td class="val"><asp:Literal ID="litInvoiceModalVendor" runat="server" /></td>
                        <td class="lbl"><i class="bi bi-upc-scan"></i>GL Number</td>
                        <td class="val"><asp:Literal ID="litInvoiceModalGL" runat="server" /></td>
                    </tr>
                    <tr>
                        <td class="lbl"><i class="bi bi-card-text"></i>Justification</td>
                        <td class="val" colspan="3"><asp:Literal ID="litInvoiceModalJustification" runat="server" /></td>
                    </tr>
                </table>
                <div class="table-responsive">
                <asp:GridView ID="gvInvoices" runat="server" AutoGenerateColumns="false" ShowFooter="true"
                    CssClass="dfm-table pet-line-tbl" GridLines="None" DataKeyNames="InvoiceID"
                    OnRowCommand="gvInvoices_RowCommand"
                    OnRowEditing="gvInvoices_RowEditing" OnRowUpdating="gvInvoices_RowUpdating" OnRowCancelingEdit="gvInvoices_RowCancelingEdit"
                    EmptyDataText="No invoices added yet.">
                    <Columns>
                        <asp:TemplateField HeaderText="Invoice ID" ItemStyle-Width="60px">
                            <ItemTemplate><%# Eval("InvoiceID") %></ItemTemplate>
                            <EditItemTemplate><%# Eval("InvoiceID") %></EditItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Invoice Number">
                            <ItemTemplate><%# Eval("InvoiceNo") %></ItemTemplate>
                            <EditItemTemplate><asp:TextBox runat="server" ID="txtEInvNo" Text='<%# Eval("InvoiceNo") %>' CssClass="form-control input-sm" /></EditItemTemplate>
                            <FooterTemplate><asp:TextBox runat="server" ID="txtNewInvNo" CssClass="form-control input-sm" placeholder="Invoice No" /></FooterTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Invoice Amount" ItemStyle-CssClass="text-right">
                            <ItemTemplate><%# Eval("InvoiceAmount", "{0:N2}") %></ItemTemplate>
                            <EditItemTemplate><asp:TextBox runat="server" ID="txtEInvAmount" Text='<%# Eval("InvoiceAmount", "{0:N2}") %>' CssClass="form-control input-sm text-right" /></EditItemTemplate>
                            <FooterTemplate><asp:TextBox runat="server" ID="txtNewInvAmount" CssClass="form-control input-sm text-right" Text="0" /></FooterTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Invoice Status">
                            <ItemTemplate><%# Eval("InvoiceStatus") %></ItemTemplate>
                            <EditItemTemplate>
                                <asp:DropDownList runat="server" ID="ddlEInvStatus" CssClass="form-control input-sm" SelectedValue='<%# Eval("InvoiceStatus") %>'>
                                    <asp:ListItem Text="None" Value="" />
                                    <asp:ListItem Text="Generated / Created" Value="Generated / Created" />
                                    <asp:ListItem Text="Sent" Value="Sent" />
                                    <asp:ListItem Text="In Approval / Pending" Value="In Approval / Pending" />
                                    <asp:ListItem Text="Ready for Payment" Value="Ready for Payment" />
                                    <asp:ListItem Text="Payment in Transit" Value="Payment in Transit" />
                                    <asp:ListItem Text="Paid" Value="Paid" />
                                    <asp:ListItem Text="Rejected / Removed" Value="Rejected / Removed" />
                                    <asp:ListItem Text="Disputed" Value="Disputed" />
                                    <asp:ListItem Text="Processed / Archived" Value="Processed / Archived" />
                                </asp:DropDownList>
                            </EditItemTemplate>
                            <FooterTemplate>
                                <asp:DropDownList runat="server" ID="ddlNewInvStatus" CssClass="form-control input-sm">
                                    <asp:ListItem Text="None" Value="" />
                                    <asp:ListItem Text="Generated / Created" Value="Generated / Created" />
                                    <asp:ListItem Text="Sent" Value="Sent" />
                                    <asp:ListItem Text="In Approval / Pending" Value="In Approval / Pending" />
                                    <asp:ListItem Text="Ready for Payment" Value="Ready for Payment" />
                                    <asp:ListItem Text="Payment in Transit" Value="Payment in Transit" />
                                    <asp:ListItem Text="Paid" Value="Paid" />
                                    <asp:ListItem Text="Rejected / Removed" Value="Rejected / Removed" />
                                    <asp:ListItem Text="Disputed" Value="Disputed" />
                                    <asp:ListItem Text="Processed / Archived" Value="Processed / Archived" />
                                </asp:DropDownList>
                            </FooterTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Payment Date">
                            <ItemTemplate><%# Eval("PaymentDate", "{0:dd-MMM-yyyy}") %></ItemTemplate>
                            <EditItemTemplate><asp:TextBox runat="server" ID="txtEInvPaymentDate" Text='<%# Eval("PaymentDate","{0:yyyy-MM-dd}") %>' CssClass="form-control input-sm" TextMode="Date" /></EditItemTemplate>
                            <FooterTemplate><asp:TextBox runat="server" ID="txtNewInvPaymentDate" CssClass="form-control input-sm" TextMode="Date" /></FooterTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Action">
                            <ItemTemplate>
                                <% if (CanManageBudget) { %>
                                <div class="gv-acts">
                                    <asp:LinkButton runat="server" CssClass="btn btn-xs btn-primary" CommandName="Edit" ToolTip="Grid edit"><i class="bi bi-pencil"></i></asp:LinkButton>
                                    <asp:LinkButton runat="server" CssClass="btn btn-xs btn-danger" CommandName="DelInvoice" CommandArgument='<%# Eval("InvoiceID") %>' OnClientClick="return confirm('Delete this invoice?')"><i class="bi bi-trash"></i></asp:LinkButton>
                                </div>
                                <% } %>
                            </ItemTemplate>
                            <EditItemTemplate>
                                <div class="gv-acts">
                                    <asp:LinkButton runat="server" CssClass="btn btn-xs btn-success" CommandName="Update"><i class="bi bi-check-lg"></i></asp:LinkButton>
                                    <asp:LinkButton runat="server" CssClass="btn btn-xs btn-default" CommandName="Cancel"><i class="bi bi-x-lg"></i></asp:LinkButton>
                                </div>
                            </EditItemTemplate>
                            <FooterTemplate>
                                <% if (CanManageBudget) { %>
                                <asp:LinkButton runat="server" ID="btnAddInvoiceFooter" CssClass="btn btn-xs btn-success" CommandName="AddInvoice" ToolTip="Add invoice"><i class="bi bi-plus-circle"></i> Add</asp:LinkButton>
                                <% } %>
                            </FooterTemplate>
                        </asp:TemplateField>
                    </Columns>
                    <EmptyDataTemplate>
                        <div style="padding:10px 4px;">
                            <div style="color:#64748b;font-size:.85em;margin-bottom:8px;">No invoices added yet.</div>
                            <% if (CanManageBudget) { %>
                            <div style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end;">
                                <div class="form-group" style="margin:0;">
                                    <label style="font-size:.75em;display:block;">Invoice Number</label>
                                    <asp:TextBox runat="server" ID="txtNewInvNo" CssClass="form-control input-sm" placeholder="Invoice No" />
                                </div>
                                <div class="form-group" style="margin:0;">
                                    <label style="font-size:.75em;display:block;">Invoice Amount</label>
                                    <asp:TextBox runat="server" ID="txtNewInvAmount" CssClass="form-control input-sm text-right" Text="0" />
                                </div>
                                <div class="form-group" style="margin:0;">
                                    <label style="font-size:.75em;display:block;">Invoice Status</label>
                                    <asp:DropDownList runat="server" ID="ddlNewInvStatus" CssClass="form-control input-sm">
                                        <asp:ListItem Text="None" Value="" />
                                        <asp:ListItem Text="Generated / Created" Value="Generated / Created" />
                                        <asp:ListItem Text="Sent" Value="Sent" />
                                        <asp:ListItem Text="In Approval / Pending" Value="In Approval / Pending" />
                                        <asp:ListItem Text="Ready for Payment" Value="Ready for Payment" />
                                        <asp:ListItem Text="Payment in Transit" Value="Payment in Transit" />
                                        <asp:ListItem Text="Paid" Value="Paid" />
                                        <asp:ListItem Text="Rejected / Removed" Value="Rejected / Removed" />
                                        <asp:ListItem Text="Disputed" Value="Disputed" />
                                        <asp:ListItem Text="Processed / Archived" Value="Processed / Archived" />
                                    </asp:DropDownList>
                                </div>
                                <div class="form-group" style="margin:0;">
                                    <label style="font-size:.75em;display:block;">Payment Date</label>
                                    <asp:TextBox runat="server" ID="txtNewInvPaymentDate" CssClass="form-control input-sm" TextMode="Date" />
                                </div>
                                <div class="form-group" style="margin:0;">
                                    <asp:LinkButton runat="server" ID="btnAddInvoiceFooter" CssClass="btn btn-xs btn-success" CommandName="AddInvoice" ToolTip="Add invoice"><i class="bi bi-plus-circle"></i> Add</asp:LinkButton>
                                </div>
                            </div>
                            <% } %>
                        </div>
                    </EmptyDataTemplate>
                </asp:GridView>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
            </div>
        </div>
    </div>
</div>
<% } %>

<!-- PET Delete Confirmation Modal -->
<div class="modal fade" id="petFormDelModal" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document" style="max-width:460px;">
        <div class="modal-content">
            <div class="modal-header" style="background:#b91c1c;color:#fff;">
                <button type="button" class="close" data-dismiss="modal" style="color:#fff;opacity:.8;">&times;</button>
                <h4 class="modal-title"><i class="bi bi-exclamation-triangle-fill"></i> Confirm Delete Spend Request</h4>
            </div>
            <div class="modal-body" style="padding:24px;text-align:center;">
                <div style="font-size:2.8em;color:#dc2626;margin-bottom:10px;"><i class="bi bi-trash3-fill"></i></div>
                <p style="font-size:.94em;font-weight:600;color:#1e293b;margin-bottom:4px;">Are you sure you want to delete</p>
                <p style="font-size:1.1em;font-weight:800;color:#dc2626;"><%= Server.HtmlEncode(PetRefNo ?? "#" + CurrentPetFormId.ToString()) %></p>
                <p style="font-size:.82em;color:#64748b;margin-top:8px;">The Spend Request will be marked as <strong>Deleted</strong>. Workflow history is retained.</p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal"><i class="bi bi-x-lg"></i> Cancel</button>
                <asp:Button ID="btnDeletePet" runat="server" CssClass="btn btn-danger"
                    Text="Yes, Delete" OnClick="btnDeletePet_Click" CausesValidation="false" />
            </div>
        </div>
    </div>
</div>

</asp:Content>
